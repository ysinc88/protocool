require "open3"
require "etc"

# Local Hebrew transcription with speaker separation:
#   1. ffmpeg      -> 16 kHz mono wav
#   2. sherpa-onnx -> who spoke when (pyannote segmentation + speaker embeddings, CPU)
#   3. whisper.cpp -> ivrit.ai whisper-large-v3 on the GPU, word-level timestamps
#   4. each word goes to the speaker active at its midpoint, speaker changes snap to the nearest
#      natural break, and consecutive words merge into turns
# Progress (stage + percent) is written to the recording as the tools report it.
class Transcriber
  class Error < StandardError; end

  # Everything bin/setup-ml installs lives under PROTOCOOL_ML_DIR.
  ML = ENV.fetch("PROTOCOOL_ML_DIR", File.join(Dir.home, ".local/share/protocool"))
  WHISPER = ENV.fetch("PROTOCOOL_WHISPER", "#{ML}/whisper.cpp/build/bin/whisper-cli")
  MODEL = ENV.fetch("PROTOCOOL_WHISPER_MODEL", "#{ML}/models/ggml-ivrit-large-v3.bin")
  # Same model quantized to 8 bits (~1.7 GB): used when the GPU is short on memory.
  MODEL_Q8 = ENV.fetch("PROTOCOOL_WHISPER_MODEL_Q8", "#{ML}/models/ggml-ivrit-large-v3-q8_0.bin")
  LANGUAGE = ENV.fetch("PROTOCOOL_LANGUAGE", "he")
  SHERPA = "#{ML}/sherpa"
  DIARIZE = "#{SHERPA}/bin/sherpa-onnx-offline-speaker-diarization"
  SEGMENTATION = "#{SHERPA}/sherpa-onnx-pyannote-segmentation-3-0/model.onnx"
  EMBEDDING = "#{SHERPA}/3dspeaker_speech_campplus_sv_zh_en_16k-common_advanced.onnx"
  MIN_SPEAKER_SECONDS = 6
  SNAP_WORDS = 3

  def initialize(recording)
    @recording = recording
  end

  def call
    Dir.mktmpdir("protocool") do |tmp|
      wav = File.join(tmp, "audio.wav")
      stage!("converting")
      run!("ffmpeg", "-loglevel", "error", "-y", "-i", @recording.audio_path.to_s, "-ac", "1", "-ar", "16000", wav)
      duration = run!("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", wav).to_f
      turns = diarize(wav)
      words = transcribe(wav, tmp)
      segments = merge(words, turns)
      @recording.update!(segments:, duration_seconds: duration, status: "done", error: nil, finished_at: Time.current,
                         stage: nil, progress: nil)
    end
  end

  private

  def diarize(wav)
    n = @recording.num_speakers.to_i
    clustering = n > 0 ? "--clustering.num-clusters=#{n}" : "--clustering.cluster-threshold=0.9"
    threads = [ Etc.nprocessors, 8 ].min
    stage!("diarizing")
    out = run!(DIARIZE, "--segmentation.pyannote-model=#{SEGMENTATION}", "--embedding.model=#{EMBEDDING}",
               "--segmentation.pyannote-window-shift-ratio=0.5",
               "--segmentation.num-threads=#{threads}", "--embedding.num-threads=#{threads}", clustering, wav,
               &progress_from(/^progress ([\d.]+)%/))
    turns = out.lines.filter_map do |l|
      m = l.match(/([\d.]+)\s+--\s+([\d.]+)\s+(speaker_\d+)/) or next
      { start: m[1].to_f, end: m[2].to_f, speaker: m[3] }
    end
    tidy(turns, merge_small: n <= 0)
  end

  # Without a known speaker count the clustering tends to invent "voices" that speak for
  # a second or two; fold those into the neighbouring turn. Then renumber by first appearance.
  def tidy(turns, merge_small:)
    if merge_small
      totals = turns.group_by { |t| t[:speaker] }.transform_values { |ts| ts.sum { |t| t[:end] - t[:start] } }
      small = totals.select { |_, d| d < MIN_SPEAKER_SECONDS }.keys
      if small.size < totals.size
        turns.each_with_index do |t, i|
          next unless small.include?(t[:speaker])
          neighbour = [ (turns[i - 1] if i.positive?), turns[i + 1] ].compact.reject { |x| small.include?(x[:speaker]) }
                        .min_by { |x| [ (x[:end] - t[:start]).abs, (x[:start] - t[:end]).abs ].min }
          t[:speaker] = neighbour[:speaker] if neighbour
        end
      end
    end
    order = turns.map { |t| t[:speaker] }.uniq
    turns.each { |t| t[:speaker] = format("speaker_%02d", order.index(t[:speaker])) }
  end

  def transcribe(wav, tmp)
    base = File.join(tmp, "asr")
    attempts = [ [ MODEL, [] ], [ MODEL_Q8, [] ], [ MODEL_Q8, [ "-ng" ] ] ].select { |m, _| File.exist?(m) }
    attempts.each_with_index do |(model, extra), i|
      stage!("transcribing")
      run!(WHISPER, "-m", model, "-l", LANGUAGE, "-f", wav, "-oj", "-of", base, "-ml", "1", "-sow", "-np", "-pp", *extra,
           "--prompt", initial_prompt, env: gpu_env,
           &progress_from(/progress =\s*(\d+)%/))
      break
    rescue Error => e
      raise if i == attempts.size - 1
      Rails.logger.warn("whisper failed with #{File.basename(model)} #{extra.join(' ')}, falling back: #{e.message.truncate(200)}")
    end
    JSON.parse(File.read("#{base}.json"))["transcription"].filter_map do |s|
      text = s["text"].to_s.strip
      next if text.empty?
      { start: s["offsets"]["from"] / 1000.0, end: s["offsets"]["to"] / 1000.0, text: }
    end
  end

  # On machines with an integrated + discrete GPU, point Vulkan at the discrete one
  # (index from `vulkaninfo --summary`).
  def gpu_env
    ENV["PROTOCOOL_VK_DEVICE"].present? ? { "GGML_VK_VISIBLE_DEVICES" => ENV["PROTOCOOL_VK_DEVICE"] } : {}
  end

  def merge(words, turns)
    speakers = words.map { |w| speaker_at(turns, (w[:start] + w[:end]) / 2) }
    snap_changes!(words, speakers)
    segments = []
    words.zip(speakers).each do |w, speaker|
      last = segments.last
      if last && (last["speaker"] == speaker || speaker.nil?) && w[:start] - last["end"] < 3
        last["text"] << " " << w[:text]
        last["end"] = w[:end]
      else
        segments << { "speaker" => speaker || last&.dig("speaker") || "speaker_00", "start" => w[:start], "end" => w[:end], "text" => w[:text].dup }
      end
    end
    segments.each { |s| s["text"] = s["text"].gsub(/\s+([,.?!:;])/, '\1').squeeze(" ") }
  end

  # Word timestamps are loose, so a midpoint split often hands the first or last word of a turn
  # to the neighbour ("...תוסיפי. רציתי" | "להגיד..."). Move each speaker change, within a few
  # words, to the most natural break: after a sentence end, else a comma, else the longest pause.
  def snap_changes!(words, speakers)
    i = 1
    while i < words.size
      prev, nxt = speakers[i - 1], speakers[i]
      if prev == nxt || prev.nil? || nxt.nil?
        i += 1
        next
      end
      # A change at j means words[j - 1] stays prev and words[j] goes to nxt; never cross another change.
      lo = i
      lo -= 1 while lo > 1 && i - lo < SNAP_WORDS && speakers[lo - 2] == prev
      hi = i
      hi += 1 while hi < words.size - 1 && hi - i < SNAP_WORDS && speakers[hi + 1] == nxt
      best = (lo..hi).max_by { |j| [ break_score(words, j), -(j - i).abs ] }
      (best...i).each { |k| speakers[k] = nxt }
      (i...best).each { |k| speakers[k] = prev }
      i = best + 1
    end
  end

  def break_score(words, j)
    punct = case words[j - 1][:text]
    when /[.?!…]["”']?\z/ then 2
    when /[,;:]["”']?\z/ then 1
    else 0
    end
    punct + (words[j][:start] - words[j - 1][:end]).clamp(0, 1)
  end

  def speaker_at(turns, t)
    hit = turns.find { |x| t.between?(x[:start], x[:end]) }
    return hit[:speaker] if hit
    turns.min_by { |x| [ (x[:start] - t).abs, (x[:end] - t).abs ].min }&.dig(:speaker)
  end

  def initial_prompt
    names = Member.active.map(&:name).join(", ")
    "פגישת #{Setting.current.committee_name}. משתתפים: #{names}. שלום לכולם, נתחיל בסדר היום. מה דעתכם? כן, בסדר."
  end

  def stage!(stage)
    @recording.update_columns(stage:, progress: 0)
  end

  # Turns a tool's progress lines into progress writes, at most one per whole percent.
  def progress_from(pattern)
    lambda do |line|
      pct = line[pattern, 1]&.to_f&.floor or next
      @recording.update_columns(progress: pct) if pct > @recording.progress.to_i
    end
  end

  # Streams stderr line by line to the block (progress), stdout is read whole.
  def run!(*cmd, env: {}, &on_err_line)
    out, err, status = Open3.popen3(env, *cmd) do |stdin, stdout, stderr, wait|
      stdin.close
      reader = Thread.new { stdout.read }
      log = +""
      stderr.each_line do |line|
        log << line
        on_err_line&.call(line)
      end
      [ reader.value, log, wait.value ]
    end
    raise Error, "#{File.basename(cmd.first)} נכשל: #{err.lines.last(5).join}".truncate(1000) unless status.success?
    out
  end
end

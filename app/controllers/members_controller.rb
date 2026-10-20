class MembersController < ApplicationController
  before_action :set_member, only: %i[edit update destroy]

  def index
    @members = Member.order(active: :desc, name: :asc)
    @member = Member.new
  end

  def create
    @member = Member.new(member_params)
    if @member.save
      redirect_to members_path, notice: "#{@member.name} נוסף/ה לוועדה"
    else
      @members = Member.order(active: :desc, name: :asc)
      render :index, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @member.update(member_params)
      redirect_to members_path, notice: "הפרטים עודכנו"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @member.destroy
    redirect_to members_path, notice: "#{@member.name} הוסר/ה"
  end

  private

  def set_member = @member = Member.find(params[:id])
  def member_params = params.expect(member: %i[name email role active])
end

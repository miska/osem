class Admin::RegistrationsController < ApplicationController
  before_filter :verify_organizer

  def show
    session[:return_to] ||= request.referer
    @pdf_filename = "#{@conference.title}.pdf"
    @registrations = @conference.registrations.all(:joins => :person,
                                                   :order => "registrations.created_at ASC",
                                                   :select => "registrations.*,
                                                               people.last_name AS last_name,
                                                               people.first_name AS first_name,
                                                               people.public_name AS public_name,
                                                               people.email AS email")

    @attended = @conference.registrations.where("attended = ?", true)
    @headers = %w[attended name email social_events attending_with_partner need_access other_needs arrival departure]
  end

  def change_field
      @registration = Registration.find(params[:id])
      field = params[:view_field]
      if @registration.send(field.to_sym)
        @registration.update_attribute(:"#{field}",0)
      else
        @registration.update_attribute(:"#{field}",1)
      end

      redirect_to admin_conference_registrations_path(@conference.short_title, @registration)
      flash[:notice] = "Updated '#{params[:view_field]}' for #{(Person.where("id = ?", @registration.person_id).first).email}"
  end
  
  def edit
    @registration = @conference.registrations.where("id = ?", params[:id]).first
    @person = Person.where("id = ?", @registration.person_id).first
  end

  def update
    reg_id = params[:format]
    @registration = @conference.registrations.where("id = ?", reg_id).first
    @person = Person.where("id = ?", @registration.person_id).first
    begin
      @person.update_attributes!(params[:registration][:person_attributes])
      params[:registration].delete :person_attributes
      @registration.supporter_registration = @conference.supporter_registrations.new(params[:registration][:supporter_registration_attributes])
      params[:registration].delete :supporter_registration_attributes
      @registration.update_attributes!(params[:registration])
      flash[:notice] = "Successfully updated Registration for #{@person.public_name} #{@person.email}"
      redirect_to(admin_conference_registrations_path(@conference.short_title))
    rescue Exception => e
      Rails.logger.debug e.backtrace.join("\n")
      redirect_to(admin_conference_registrations_path(@conference.short_title), :alert => 'Failed to update registration:' + e.message)
      return
    end
  end

  def delete
    if has_role?(current_user, "Admin")
      registration = @conference.registrations.where(:id => params[:id]).first
      person = Person.where("id = ?", registration.person_id).first

      begin registration.destroy
        redirect_to admin_conference_registrations_path
        flash[:notice] = "Deleted registration for #{person.public_name} #{person.email}"
      rescue Exception => e
        Rails.logger.debug e.backtrace.join("\n")
        redirect_to(admin_conference_registrations_path(@conference.short_title), :alert => 'Failed to delete registration:' + e.message)
        return
      end
    else
      redirect_to(admin_conference_registrations_path(@conference.short_title), :alert => 'You must be an admin to delete a registration.')
    end
  end
end
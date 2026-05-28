class Admin::Fraud::DashboardsController < Admin::ApplicationController
  def show
    authorize [ :admin, :fraud, :dashboard ]
  end
end

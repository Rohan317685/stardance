# frozen_string_literal: true

# One combined review page per hardware project. A hardware project moves
# through two stages — design (a Certification::FundingRequest, which offers the
# grant) and build (a Certification::Ship). Some builders skip design and start
# at build when they don't want a grant. This page shows both stages side by
# side, clearly marks which one is currently up for review, and lets the
# reviewer act on whichever is pending.
#
# It owns no mutations: the design/build verdict forms and claim buttons post to
# the existing funding/ship endpoints with a redirect_to_hardware param, which
# sends the reviewer back here. Those endpoints keep their PaperTrail audit
# trail, so nothing about the audit history changes.
class Admin::Certification::HardwareReviewsController < Admin::Certification::ApplicationController
  before_action -> { head :not_found unless Flipper.enabled?(:hardware_flow, current_user) }
  before_action :set_project
  before_action -> { head :not_found unless @project.hardware? }
  before_action :set_body_class

  # GET /admin/certification/hardware/:project_id
  def show
    authorize @project, policy_class: Admin::Certification::HardwareReviewPolicy

    @funding_request = @project.latest_funding_request
    @ship = @project.ship_reviews.order(created_at: :desc).first
    @owner = review_owner

    # The stage that's actually actionable right now drives the banner + accent.
    @active_stage =
      if @funding_request&.pending?
        :design
      elsif @ship&.pending?
        :build
      end

    @reviewed_today = ::Certification::FundingRequest.reviewed_today(current_user) +
                      ::Certification::Ship.reviewed_today(current_user)

    @lapse_timelapses = lapse_timelapses_for_review
    @lookout_recordings = lookout_recordings_for_review
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def review_owner
    @review_owner ||= @project.memberships.owner.first&.user
  end

  # Mirrors the funding queue: provider URLs expire after ~1h, so a short cache
  # keyed by project kills the per-render HTTP fan-out without staling them.
  RECORDINGS_CACHE_TTL = 1.minute

  def lapse_timelapses_for_review
    Rails.cache.fetch([ "hardware_review_recordings", "lapse", @project.id ], expires_in: RECORDINGS_CACHE_TTL) do
      LapseService.timelapses_for_project(
        hackatime_user_id: review_owner&.hackatime_identity&.uid,
        project_keys: @project.hackatime_keys
      )
    end
  end

  def lookout_recordings_for_review
    Rails.cache.fetch([ "hardware_review_recordings", "lookout", @project.id ], expires_in: RECORDINGS_CACHE_TTL) do
      LookoutService.recordings_for_project(@project)
    end
  end

  # The .app-layout wrapper reserves the sidebar gutter itself; this body class
  # zeroes the body's own sidebar margin so the two don't stack into a huge gap.
  def set_body_class
    @body_class = "app-layout-page"
  end
end

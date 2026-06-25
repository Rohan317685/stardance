require "test_helper"

class Admin::Certification::HardwareReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Flipper.enable(:hardware_flow)
    @reviewer = create_user(slack_id: "U_HW_REVIEW_REVIEWER", display_name: "hw_review_reviewer")
    @reviewer.update!(granted_roles: [ "project_certifier" ])
    @owner = create_user(slack_id: "U_HW_REVIEW_OWNER", display_name: "hw_review_owner")

    @project = Project.create!(title: "HW review #{SecureRandom.hex(4)}", hardware_stage: "design")
    Project::Membership.create!(project: @project, user: @owner, role: :owner)
    @funding = Certification::FundingRequest.new(
      project: @project, user: @owner, complexity_tier: 1, requested_amount_cents: 2_000, status: :pending
    )
    @funding.save!(validate: false) # skip the create-only "needs a devlog" gate
  end

  test "renders the combined page with both stages for a reviewer" do
    sign_in @reviewer

    get admin_certification_hardware_review_path(@project)

    assert_response :success
    assert_select "h2.hardware-review__stage-title", text: "Design review"
    assert_select "h2.hardware-review__stage-title", text: "Build review"
    # The design stage is the one pending, so the active banner names it.
    assert_select ".hardware-review__banner--design"
  end

  test "404s when the hardware flow flag is off" do
    Flipper.disable(:hardware_flow)
    sign_in @reviewer

    get admin_certification_hardware_review_path(@project)

    assert_response :not_found
  end

  test "404s for a non-hardware (software) project" do
    software = Project.create!(title: "Software #{SecureRandom.hex(4)}")
    Project::Membership.create!(project: software, user: @owner, role: :owner)
    sign_in @reviewer

    get admin_certification_hardware_review_path(software)

    assert_response :not_found
  end

  test "claiming the design review with redirect_to_hardware returns to the combined page" do
    sign_in @reviewer

    post admin_certification_funding_request_claim_path(@funding),
         params: { redirect_to_hardware: @project.id }

    assert_redirected_to admin_certification_hardware_review_path(@project)
    assert_equal @reviewer.id, @funding.reload.reviewer_id
  end
end

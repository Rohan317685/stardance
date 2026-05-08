require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(slack_id: "U_PROJECT_OWNER", display_name: "owner", email: "owner@example.test")
    @viewer = User.create!(slack_id: "U_PROJECT_VIEWER", display_name: "viewer", email: "viewer@example.test")
    @project = Project.create!(title: "Forest Odyssey", description: "Explore a magical forest")
    @project.memberships.create!(user: @owner, role: :owner)
  end

  test "owner sees inline project editing form on show" do
    sign_in @owner

    get project_path(@project)

    assert_response :success
    assert_select "form.project-show--editing[action=?]", project_path(@project)
    assert_select "input[name='project[title]'][value=?]", "Forest Odyssey"
    assert_select "textarea[name='project[description]']", text: "Explore a magical forest"
    assert_select "[data-controller='hackatime-project-selector'] select:not([multiple])"
    assert_select "input[name='inline_project_show'][value='1']", 1
  end

  test "owner can update project from inline show form" do
    sign_in @owner

    patch project_path(@project), params: {
      inline_project_show: "1",
      project: {
        title: "Forest Odyssey DX",
        description: "A brighter forest",
        demo_url: "",
        repo_url: "",
        readme_url: "",
        ai_declaration: "Used AI to rubber-duck CSS."
      }
    }

    assert_redirected_to project_path(@project)
    @project.reload
    assert_equal "Forest Odyssey DX", @project.title
    assert_equal "A brighter forest", @project.description
    assert_equal "Used AI to rubber-duck CSS.", @project.ai_declaration
  end

  test "non-owner sees read-only project shell" do
    sign_in @viewer

    get project_path(@project)

    assert_response :success
    assert_select "form.project-show--editing", 0
    assert_select ".project-show__title", text: "Forest Odyssey"
  end

  test "non-owner cannot update project" do
    sign_in @viewer

    patch project_path(@project), params: {
      inline_project_show: "1",
      project: { title: "Not yours" }
    }

    assert_response :forbidden
    assert_equal "Forest Odyssey", @project.reload.title
  end
end

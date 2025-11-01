# frozen_string_literal: true

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get login_path
    assert_response :success
    assert_select "h2", "Sign In"
  end

  test "should create session with valid credentials" do
    user = users(:one)
    post session_path, params: { user: { email: user.email, password: "password" } }

    assert_redirected_to root_path
    assert_equal "Welcome back!", flash[:notice]
    assert_equal user.id, session[:user_id]
  end

  test "should not create session with invalid email" do
    post session_path, params: { user: { email: "nonexistent@example.com", password: "password" } }

    assert_response :unprocessable_entity
    assert_equal "Invalid email or password", flash[:alert]
    assert_nil session[:user_id]
  end

  test "should not create session with invalid password" do
    user = users(:one)
    post session_path, params: { user: { email: user.email, password: "wrongpassword" } }

    assert_response :unprocessable_entity
    assert_equal "Invalid email or password", flash[:alert]
    assert_nil session[:user_id]
  end

  test "should destroy session" do
    user = users(:one)
    log_in_as(user)

    delete logout_path

    assert_redirected_to root_path
    assert_equal "You have been signed out.", flash[:notice]
    assert_nil session[:user_id]
  end

  test "should redirect logged in user away from login" do
    user = users(:one)
    log_in_as(user)

    get login_path
    assert_redirected_to root_path
    assert_equal "You are already signed in.", flash[:notice]
  end
end
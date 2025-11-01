# frozen_string_literal: true

require "spec_helper"
require "action_dispatch/testing/test_request"
require "action_dispatch/testing/assertions/response"

RSpec.describe SessionsController, type: :controller do
  let(:user) { User.create!(email: "user@example.com", password: "password123", password_confirmation: "password123") }

  describe "GET #new" do
    it "returns success when not logged in" do
      get :new

      expect(response).to be_successful
      expect(assigns(:user)).to be_a_new(User)
    end

    it "redirects when already logged in" do
      session[:user_id] = user.id
      get :new

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to be_present
    end
  end

  describe "POST #create" do
    context "with valid credentials" do
      it "logs in the user and redirects to root path" do
        post :create, params: { user: { email: user.email, password: "password123" } }

        expect(session[:user_id]).to eq(user.id)
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq("Welcome back!")
      end

      it "handles email case-insensitivity" do
        post :create, params: { user: { email: user.email.upcase, password: "password123" } }

        expect(session[:user_id]).to eq(user.id)
      end

      it "handles email with extra whitespace" do
        post :create, params: { user: { email: "  #{user.email}  ", password: "password123" } }

        expect(session[:user_id]).to eq(user.id)
      end
    end

    context "with invalid credentials" do
      it "does not log in with wrong password" do
        post :create, params: { user: { email: user.email, password: "wrongpassword" } }

        expect(session[:user_id]).to be_nil
        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash[:alert]).to eq("Invalid email or password")
      end

      it "does not log in with non-existent email" do
        post :create, params: { user: { email: "nonexistent@example.com", password: "password123" } }

        expect(session[:user_id]).to be_nil
        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash[:alert]).to eq("Invalid email or password")
      end

      it "does not log in with blank email" do
        post :create, params: { user: { email: "", password: "password123" } }

        expect(session[:user_id]).to be_nil
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE #destroy" do
    before do
      session[:user_id] = user.id
    end

    it "logs out the user" do
      delete :destroy

      expect(session[:user_id]).to be_nil
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("You have been signed out.")
    end

    it "redirects to login when unauthenticated" do
      session.delete(:user_id)
      delete :destroy

      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq("Please sign in to continue.")
    end
  end
end

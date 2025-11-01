# frozen_string_literal: true

require "spec_helper"
require "action_dispatch/testing/test_request"
require "action_dispatch/testing/assertions/response"

RSpec.describe UsersController, type: :controller do
  let(:existing_user) { User.create!(email: "existing@example.com", password: "password123", password_confirmation: "password123") }

  describe "GET #new" do
    it "returns success when not logged in" do
      get :new

      expect(response).to be_successful
      expect(assigns(:user)).to be_a_new(User)
    end

    it "redirects when already logged in" do
      session[:user_id] = existing_user.id
      get :new

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to be_present
    end
  end

  describe "POST #create" do
    context "with valid attributes" do
      let(:valid_params) do
        {
          user: {
            email: "newuser@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end

      it "creates a new user" do
        expect {
          post :create, params: valid_params
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.email).to eq("newuser@example.com")
        expect(user.authenticate("password123")).to eq(user)
      end

      it "logs in the new user" do
        post :create, params: valid_params

        user = User.last
        expect(session[:user_id]).to eq(user.id)
      end

      it "redirects to root path with success message" do
        post :create, params: valid_params

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq("Welcome! Your account has been created.")
      end

      it "normalizes email" do
        post :create, params: {
          user: {
            email: "  NewUser@EXAMPLE.COM  ",
            password: "password123",
            password_confirmation: "password123"
          }
        }

        user = User.last
        expect(user.email).to eq("newuser@example.com")
      end

      it "generates a feed token" do
        post :create, params: valid_params

        user = User.last
        expect(user.feed_token).to be_present
      end
    end

    context "with invalid attributes" do
      it "does not create user with blank email" do
        expect {
          post :create, params: {
            user: {
              email: "",
              password: "password123",
              password_confirmation: "password123"
            }
          }
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create user with duplicate email" do
        expect {
          post :create, params: {
            user: {
              email: existing_user.email,
              password: "password123",
              password_confirmation: "password123"
            }
          }
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create user with mismatched password confirmation" do
        expect {
          post :create, params: {
            user: {
              email: "newuser@example.com",
              password: "password123",
              password_confirmation: "different"
            }
          }
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create user with blank password" do
        expect {
          post :create, params: {
            user: {
              email: "newuser@example.com",
              password: "",
              password_confirmation: ""
            }
          }
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not log in when creation fails" do
        post :create, params: {
          user: {
            email: existing_user.email,
            password: "password123",
            password_confirmation: "password123"
          }
        }

        expect(session[:user_id]).to be_nil
      end
    end
  end
end

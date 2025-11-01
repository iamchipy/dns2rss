# frozen_string_literal: true

require "spec_helper"
require "action_dispatch/testing/test_request"
require "action_dispatch/testing/assertions/response"

RSpec.describe DnsWatchesController, type: :controller do
  let(:user) { User.create!(email: "user@example.com", password: "password123", password_confirmation: "password123") }
  let(:other_user) { User.create!(email: "other@example.com", password: "password123", password_confirmation: "password123") }

  let!(:public_watch) do
    DnsWatch.create!(
      user: user,
      domain: "public.example.com",
      record_type: "A",
      record_name: "@",
      visibility: "public"
    )
  end

  let!(:private_watch) do
    DnsWatch.create!(
      user: user,
      domain: "private.example.com",
      record_type: "A",
      record_name: "@",
      visibility: "private"
    )
  end

  let!(:other_public_watch) do
    DnsWatch.create!(
      user: other_user,
      domain: "other-public.example.com",
      record_type: "A",
      record_name: "@",
      visibility: "public"
    )
  end

  describe "GET #index" do
    it "returns success for guests" do
      get :index

      expect(response).to be_successful
    end

    it "shows public watches to guests" do
      get :index

      watches = assigns(:dns_watches)
      expect(watches).to include(public_watch)
      expect(watches).to include(other_public_watch)
      expect(watches).not_to include(private_watch)
    end

    it "shows public and owned watches to logged in users" do
      session[:user_id] = user.id
      get :index

      watches = assigns(:dns_watches)
      expect(watches).to include(public_watch)
      expect(watches).to include(private_watch)
      expect(watches).to include(other_public_watch)
    end

    it "provides a form watch for logged in users" do
      session[:user_id] = user.id
      get :index

      form_watch = assigns(:dns_watch_form)
      expect(form_watch).to be_a_new(DnsWatch)
      expect(form_watch.user_id).to eq(user.id)
      expect(form_watch.visibility).to eq("private")
    end

    it "provides an empty form watch for guests" do
      get :index

      form_watch = assigns(:dns_watch_form)
      expect(form_watch).to be_a_new(DnsWatch)
      expect(form_watch.user_id).to be_nil
    end
  end

  describe "GET #show" do
    context "with public watch" do
      it "allows guests to view" do
        get :show, params: { id: public_watch.id }

        expect(response).to be_successful
      end

      it "allows owner to view" do
        session[:user_id] = user.id
        get :show, params: { id: public_watch.id }

        expect(response).to be_successful
      end

      it "allows other users to view" do
        session[:user_id] = other_user.id
        get :show, params: { id: public_watch.id }

        expect(response).to be_successful
      end
    end

    context "with private watch" do
      it "denies access to guests" do
        expect {
          get :show, params: { id: private_watch.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "allows owner to view" do
        session[:user_id] = user.id
        get :show, params: { id: private_watch.id }

        expect(response).to be_successful
      end

      it "denies access to other users" do
        session[:user_id] = other_user.id

        expect {
          get :show, params: { id: private_watch.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "POST #create" do
    let(:valid_params) do
      {
        dns_watch: {
          domain: "newwatch.example.com",
          record_type: "A",
          record_name: "@",
          check_interval_minutes: 10,
          visibility: "public"
        }
      }
    end

    context "when authenticated" do
      before do
        session[:user_id] = user.id
      end

      it "creates a new watch" do
        expect {
          post :create, params: valid_params
        }.to change(DnsWatch, :count).by(1)

        watch = DnsWatch.last
        expect(watch.domain).to eq("newwatch.example.com")
        expect(watch.user_id).to eq(user.id)
        expect(watch.visibility).to eq("public")
      end

      it "sets interval from check_interval_minutes" do
        post :create, params: valid_params

        watch = DnsWatch.last
        expect(watch.interval_seconds).to eq(600)
      end

      it "normalizes domain and record type" do
        post :create, params: {
          dns_watch: {
            domain: "  NewWatch.EXAMPLE.COM  ",
            record_type: "mx",
            record_name: "@",
            visibility: "public"
          }
        }

        watch = DnsWatch.last
        expect(watch.domain).to eq("newwatch.example.com")
        expect(watch.record_type).to eq("MX")
      end

      it "does not create with invalid attributes" do
        expect {
          post :create, params: {
            dns_watch: {
              domain: "",
              record_type: "A",
              record_name: "@"
            }
          }
        }.not_to change(DnsWatch, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create duplicate watch" do
        expect {
          post :create, params: {
            dns_watch: {
              domain: public_watch.domain,
              record_type: public_watch.record_type,
              record_name: public_watch.record_name,
              visibility: "public"
            }
          }
        }.not_to change(DnsWatch, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when not authenticated" do
      it "redirects to login page" do
        post :create, params: valid_params

        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to eq("Please sign in to continue.")
      end

      it "does not create a watch" do
        expect {
          post :create, params: valid_params
        }.not_to change(DnsWatch, :count)
      end
    end
  end

  describe "PATCH #update" do
    let(:update_params) do
      {
        id: public_watch.id,
        dns_watch: {
          domain: "updated.example.com",
          check_interval_minutes: 20,
          visibility: "private"
        }
      }
    end

    context "when authenticated as owner" do
      before do
        session[:user_id] = user.id
      end

      it "updates the watch" do
        patch :update, params: update_params

        public_watch.reload
        expect(public_watch.domain).to eq("updated.example.com")
        expect(public_watch.interval_seconds).to eq(1200)
        expect(public_watch.visibility).to eq("private")
      end

      it "does not update with invalid attributes" do
        patch :update, params: {
          id: public_watch.id,
          dns_watch: { domain: "" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        public_watch.reload
        expect(public_watch.domain).to eq("public.example.com")
      end
    end

    context "when authenticated as different user" do
      before do
        session[:user_id] = other_user.id
      end

      it "denies access" do
        expect {
          patch :update, params: update_params
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not update the watch" do
        expect {
          patch :update, params: update_params
        }.to raise_error(ActiveRecord::RecordNotFound)

        public_watch.reload
        expect(public_watch.domain).to eq("public.example.com")
      end
    end

    context "when not authenticated" do
      it "redirects to login page" do
        patch :update, params: update_params

        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to eq("Please sign in to continue.")
      end

      it "does not update the watch" do
        patch :update, params: update_params

        public_watch.reload
        expect(public_watch.domain).to eq("public.example.com")
      end
    end
  end

  describe "DELETE #destroy" do
    context "when authenticated as owner" do
      before do
        session[:user_id] = user.id
      end

      it "deletes the watch" do
        expect {
          delete :destroy, params: { id: public_watch.id }
        }.to change(DnsWatch, :count).by(-1)

        expect { public_watch.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "deletes associated changes" do
        DnsChange.create!(
          dns_watch: public_watch,
          detected_at: Time.current,
          to_value: "1.2.3.4"
        )

        expect {
          delete :destroy, params: { id: public_watch.id }
        }.to change(DnsChange, :count).by(-1)
      end
    end

    context "when authenticated as different user" do
      before do
        session[:user_id] = other_user.id
      end

      it "denies access" do
        expect {
          delete :destroy, params: { id: public_watch.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not delete the watch" do
        expect {
          expect {
            delete :destroy, params: { id: public_watch.id }
          }.to raise_error(ActiveRecord::RecordNotFound)
        }.not_to change(DnsWatch, :count)
      end
    end

    context "when not authenticated" do
      it "redirects to login page" do
        delete :destroy, params: { id: public_watch.id }

        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to eq("Please sign in to continue.")
      end

      it "does not delete the watch" do
        expect {
          delete :destroy, params: { id: public_watch.id }
        }.not_to change(DnsWatch, :count)
      end
    end
  end
end

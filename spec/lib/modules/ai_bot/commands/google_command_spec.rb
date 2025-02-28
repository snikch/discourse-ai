#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Commands::GoogleCommand do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:bot) { DiscourseAi::AiBot::OpenAiBot.new(bot_user) }

  before { SiteSetting.ai_bot_enabled = true }

  describe "#process" do
    it "will not explode if there are no results" do
      post = Fabricate(:post)

      SiteSetting.ai_google_custom_search_api_key = "abc"
      SiteSetting.ai_google_custom_search_cx = "cx"

      json_text = { searchInformation: { totalResults: "0" } }.to_json

      stub_request(
        :get,
        "https://www.googleapis.com/customsearch/v1?cx=cx&key=abc&num=10&q=some%20search%20term",
      ).to_return(status: 200, body: json_text, headers: {})

      google = described_class.new(bot: nil, post: post, args: {}.to_json)
      info = google.process(query: "some search term").to_json

      expect(google.description_args[:count]).to eq(0)
      expect(info).to_not include("oops")
    end

    it "can generate correct info" do
      post = Fabricate(:post)

      SiteSetting.ai_google_custom_search_api_key = "abc"
      SiteSetting.ai_google_custom_search_cx = "cx"

      json_text = {
        searchInformation: {
          totalResults: "2",
        },
        items: [
          {
            title: "title1",
            link: "link1",
            snippet: "snippet1",
            displayLink: "displayLink1",
            formattedUrl: "formattedUrl1",
            oops: "do no include me ... oops",
          },
          {
            title: "title2",
            link: "link2",
            displayLink: "displayLink1",
            formattedUrl: "formattedUrl1",
            oops: "do no include me ... oops",
          },
        ],
      }.to_json

      stub_request(
        :get,
        "https://www.googleapis.com/customsearch/v1?cx=cx&key=abc&num=10&q=some%20search%20term",
      ).to_return(status: 200, body: json_text, headers: {})

      google =
        described_class.new(bot: bot, post: post, args: { query: "some search term" }.to_json)

      info = google.process(query: "some search term").to_json

      expect(google.description_args[:count]).to eq(2)
      expect(info).to include("title1")
      expect(info).to include("snippet1")
      expect(info).to include("some+search+term")
      expect(info).to include("title2")
      expect(info).to_not include("oops")

      google.invoke!

      expect(post.reload.raw).to include("some search term")

      expect { google.invoke! }.to raise_error(StandardError)
    end
  end
end

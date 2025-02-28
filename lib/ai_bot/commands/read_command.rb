#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class ReadCommand < Command
    class << self
      def name
        "read"
      end

      def desc
        "Will read a topic or a post on this Discourse instance"
      end

      def parameters
        [
          Parameter.new(
            name: "topic_id",
            description: "the id of the topic to read",
            type: "integer",
            required: true,
          ),
          Parameter.new(
            name: "post_number",
            description: "the post number to read",
            type: "integer",
            required: false,
          ),
        ]
      end
    end

    def description_args
      { title: @title, url: @url }
    end

    def process(topic_id:, post_number: nil)
      not_found = { topic_id: topic_id, description: "Topic not found" }

      @title = ""

      topic_id = topic_id.to_i

      topic = Topic.find_by(id: topic_id)
      return not_found if !topic || !Guardian.basic_user.can_see?(topic)

      @title = topic.title

      posts =
        Post.secured(Guardian.basic_user).where(topic_id: topic_id).order(:post_number).limit(40)
      @url = topic.relative_url(post_number)

      posts = posts.where("post_number = ?", post_number) if post_number

      content = +<<~TEXT.strip
        title: #{topic.title}
      TEXT

      category_names = [topic.category&.parent_category&.name, topic.category&.name].compact.join(
        " ",
      )
      content << "\ncategories: #{category_names}" if category_names.present?

      if topic.tags.length > 0
        tags = DiscourseTagging.filter_visible(topic.tags, Guardian.basic_user)
        content << "\ntags: #{tags.map(&:name).join(", ")}\n\n" if tags.length > 0
      end

      posts.each { |post| content << "\n\n#{post.username} said:\n\n#{post.raw}" }

      # TODO: 16k or 100k models can handle a lot more tokens
      content = tokenizer.truncate(content, 1500).squish

      result = { topic_id: topic_id, content: content, complete: true }
      result[:post_number] = post_number if post_number
      result
    end
  end
end

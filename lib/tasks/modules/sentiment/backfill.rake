# frozen_string_literal: true

desc "Backfill sentiment for all posts"
task "ai:sentiment:backfill", [:start_post] => [:environment] do |_, args|
  public_categories = Category.where(read_restricted: false).pluck(:id)

  Post
    .joins("INNER JOIN topics ON topics.id = posts.topic_id")
    .joins(<<~SQL)
      LEFT JOIN classification_results ON
        classification_results.target_id = posts.id AND
        classification_results.model_used = 'sentiment' AND
        classification_results.target_type = 'Post'
    SQL
    .where("classification_results.target_id IS NULL")
    .where("posts.id >= ?", args[:start_post].to_i || 0)
    .where("category_id IN (?)", public_categories)
    .where(posts: { deleted_at: nil })
    .order("posts.id ASC")
    .find_each do |post|
      print "."
      begin
        DiscourseAi::PostClassificator.new(
          DiscourseAi::Sentiment::SentimentClassification.new,
        ).classify!(post)
      rescue => e
        puts "Error: #{e.message}"
      end
    end
end

# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class BgeLargeEn < Base
        def vector_from(text)
          if SiteSetting.ai_cloudflare_workers_api_token.present?
            DiscourseAi::Inference::CloudflareWorkersAi
              .perform!(inference_model_name, { text: text })
              .dig(:result, :data)
              .first
          elsif SiteSetting.ai_hugging_face_tei_endpoint.present?
            DiscourseAi::Inference::HuggingFaceTextEmbeddings.perform!(text).first
          elsif SiteSetting.ai_embeddings_discourse_service_api_endpoint.present?
            DiscourseAi::Inference::DiscourseClassifier.perform!(
              "#{SiteSetting.ai_embeddings_discourse_service_api_endpoint}/api/v1/classify",
              inference_model_name.split("/").last,
              text,
              SiteSetting.ai_embeddings_discourse_service_api_key,
            )
          else
            raise "No inference endpoint configured"
          end
        end

        def name
          "bge-large-en"
        end

        def inference_model_name
          "baai/bge-large-en-v1.5"
        end

        def dimensions
          1024
        end

        def max_sequence_length
          512
        end

        def id
          4
        end

        def version
          1
        end

        def pg_function
          "<#>"
        end

        def pg_index_type
          "vector_ip_ops"
        end

        def tokenizer
          DiscourseAi::Tokenizer::BgeLargeEnTokenizer
        end
      end
    end
  end
end

# Copyright 2016 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "google/cloud/errors"
require "google/cloud/pubsub/credentials"
require "google/cloud/pubsub/version"
require "google/cloud/pubsub/v1"
require "google/gax/errors"

module Google
  module Cloud
    module Pubsub
      ##
      # @private Represents the GAX Pub/Sub service, including all the API
      # methods.
      class Service
        attr_accessor :project, :credentials, :host, :timeout, :client_config

        ##
        # Creates a new Service instance.
        def initialize project, credentials, host: nil, timeout: nil,
                       client_config: nil
          @project = project
          @credentials = credentials
          @host = host || "pubsub.googleapis.com"
          @timeout = timeout
          @client_config = client_config || {}
        end

        def channel
          require "grpc"
          GRPC::Core::Channel.new host, nil, chan_creds
        end

        def chan_creds
          return credentials if insecure?
          require "grpc"
          GRPC::Core::ChannelCredentials.new.compose \
            GRPC::Core::CallCredentials.new credentials.client.updater_proc
        end

        def subscriber
          return mocked_subscriber if mocked_subscriber
          @subscriber ||= begin
            V1::SubscriberApi.new(
              service_path: host,
              channel: channel,
              timeout: timeout,
              client_config: client_config,
              app_name: "gcloud-ruby",
              app_version: Google::Cloud::Pubsub::VERSION)
          end
        end
        attr_accessor :mocked_subscriber

        def publisher
          return mocked_publisher if mocked_publisher
          @publisher ||= begin
            V1::PublisherApi.new(
              service_path: host,
              channel: channel,
              timeout: timeout,
              app_name: "gcloud-ruby",
              app_version: Google::Cloud::Pubsub::VERSION)
          end
        end
        attr_accessor :mocked_publisher

        def insecure?
          credentials == :this_channel_is_insecure
        end

        ##
        # Gets the configuration of a topic.
        # Since the topic only has the name attribute,
        # this method is only useful to check the existence of a topic.
        # If other attributes are added in the future,
        # they will be returned here.
        def get_topic topic_name, options = {}
          execute do
            publisher.get_topic topic_path(topic_name, options),
                                options: default_options
          end
        end

        ##
        # Lists matching topics.
        def list_topics options = {}
          call_options = default_options
          if (token = options[:token])
            call_options = Google::Gax::CallOptions.new kwargs: default_headers,
                                                        page_token: token
          end

          execute do
            paged_enum = publisher.list_topics project_path(options),
                                               page_size: options[:max],
                                               options: call_options

            paged_enum.page.response
          end
        end

        ##
        # Creates the given topic with the given name.
        def create_topic topic_name, options = {}
          execute do
            publisher.create_topic topic_path(topic_name, options),
                                   options: default_options
          end
        end

        ##
        # Deletes the topic with the given name. All subscriptions to this topic
        # are also deleted. Raises GRPC status code 5 if the topic does not
        # exist. After a topic is deleted, a new topic may be created with the
        # same name.
        def delete_topic topic_name
          execute do
            publisher.delete_topic topic_path(topic_name),
                                   options: default_options
          end
        end

        ##
        # Adds one or more messages to the topic.
        # Raises GRPC status code 5 if the topic does not exist.
        # The messages parameter is an array of arrays.
        # The first element is the data, second is attributes hash.
        def publish topic, messages
          messages = messages.map do |data, attributes|
            Google::Pubsub::V1::PubsubMessage.new(
              data: data, attributes: attributes)
          end

          execute do
            publisher.publish topic_path(topic), messages,
                              options: default_options
          end
        end

        ##
        # Gets the details of a subscription.
        def get_subscription subscription_name, options = {}
          subscription = subscription_path(subscription_name, options)
          execute do
            subscriber.get_subscription subscription, options: default_options
          end
        end

        ##
        # Lists matching subscriptions by project and topic.
        def list_topics_subscriptions topic, options = {}
          call_options = default_options
          if (token = options[:token])
            call_options = Google::Gax::CallOptions.new kwargs: default_headers,
                                                        page_token: token
          end

          execute do
            paged_enum = publisher.list_topic_subscriptions \
              topic_path(topic, options),
              page_size: options[:max],
              options: call_options

            paged_enum.page.response
          end
        end

        ##
        # Lists matching subscriptions by project.
        def list_subscriptions options = {}
          call_options = default_options
          if (token = options[:token])
            call_options = Google::Gax::CallOptions.new kwargs: default_headers,
                                                        page_token: token
          end

          execute do
            paged_enum = subscriber.list_subscriptions project_path(options),
                                                       page_size: options[:max],
                                                       options: call_options

            paged_enum.page.response
          end
        end

        ##
        # Creates a subscription on a given topic for a given subscriber.
        def create_subscription topic, subscription_name, options = {}
          name = subscription_path(subscription_name, options)
          topic = topic_path(topic)
          push_config = if options[:endpoint]
                          Google::Pubsub::V1::PushConfig.new \
                            push_endpoint: options[:endpoint],
                            attributes: (options[:attributes] || {}).to_h
                        end
          deadline = options[:deadline]

          execute do
            subscriber.create_subscription name,
                                           topic,
                                           push_config: push_config,
                                           ack_deadline_seconds: deadline,
                                           options: default_options
          end
        end

        ##
        # Deletes an existing subscription.
        # All pending messages in the subscription are immediately dropped.
        def delete_subscription subscription
          execute do
            subscriber.delete_subscription subscription_path(subscription),
                                           options: default_options
          end
        end

        ##
        # Pulls a single message from the server.
        def pull subscription, options = {}
          subscription = subscription_path(subscription, options)
          max_messages = options.fetch(:max, 100).to_i
          return_immediately = !(!options.fetch(:immediate, true))

          execute do
            subscriber.pull subscription,
                            max_messages,
                            return_immediately: return_immediately,
                            options: default_options
          end
        end

        ##
        # Acknowledges receipt of a message.
        def acknowledge subscription, *ack_ids
          execute do
            subscriber.acknowledge subscription_path(subscription), ack_ids,
                                   options: default_options
          end
        end

        ##
        # Modifies the PushConfig for a specified subscription.
        def modify_push_config subscription, endpoint, attributes
          subscription = subscription_path(subscription)
          # Convert attributes to strings to match the protobuf definition
          attributes = Hash[attributes.map { |k, v| [String(k), String(v)] }]
          push_config = Google::Pubsub::V1::PushConfig.new(
            push_endpoint: endpoint,
            attributes: attributes
          )

          execute do
            subscriber.modify_push_config subscription, push_config,
                                          options: default_options
          end
        end

        ##
        # Modifies the ack deadline for a specific message.
        def modify_ack_deadline subscription, ids, deadline
          execute do
            subscriber.modify_ack_deadline subscription_path(subscription),
                                           Array(ids),
                                           deadline, options: default_options
          end
        end

        def get_topic_policy topic_name, options = {}
          execute do
            publisher.get_iam_policy topic_path(topic_name, options),
                                     options: default_options
          end
        end

        def set_topic_policy topic_name, new_policy, options = {}
          resource = topic_path(topic_name, options)

          execute do
            publisher.set_iam_policy resource, new_policy,
                                     options: default_options
          end
        end

        def test_topic_permissions topic_name, permissions, options = {}
          resource = topic_path(topic_name, options)

          execute do
            publisher.test_iam_permissions resource, permissions,
                                           options: default_options
          end
        end

        def get_subscription_policy subscription_name, options = {}
          resource = subscription_path(subscription_name, options)

          execute do
            subscriber.get_iam_policy resource, options: default_options
          end
        end

        def set_subscription_policy subscription_name, new_policy, options = {}
          resource = subscription_path(subscription_name, options)

          execute do
            subscriber.set_iam_policy resource, new_policy,
                                      options: default_options
          end
        end

        def test_subscription_permissions subscription_name,
                                          permissions, options = {}
          resource = subscription_path(subscription_name, options)

          execute do
            subscriber.test_iam_permissions resource, permissions,
                                            options: default_options
          end
        end

        def project_path options = {}
          project_name = options[:project] || project
          "projects/#{project_name}"
        end

        def topic_path topic_name, options = {}
          return topic_name if topic_name.to_s.include? "/"
          "#{project_path(options)}/topics/#{topic_name}"
        end

        def subscription_path subscription_name, options = {}
          return subscription_name if subscription_name.to_s.include? "/"
          "#{project_path(options)}/subscriptions/#{subscription_name}"
        end

        def inspect
          "#{self.class}(#{@project})"
        end

        protected

        def default_headers
          { "google-cloud-resource-prefix" => "projects/#{@project}" }
        end

        def default_options
          Google::Gax::CallOptions.new kwargs: default_headers
        end

        def execute
          yield
        rescue Google::Gax::GaxError => e
          # GaxError wraps BadStatus, but exposes it as #cause
          raise Google::Cloud::Error.from_error(e.cause)
        end
      end
    end
  end
end

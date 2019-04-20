# Gcpc

**G**oogle **C**loud **P**ub/Sub **C**lient for Ruby.

Gcpc provides the implementation of the publisher / subscriber for [Google Cloud Pub/Sub](https://cloud.google.com/pubsub/). You can add some functionality to the publisher / subscriber as interceptors.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gcpc'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install gcpc

## Usage

`gcpc` have publisher and subscriber implementation of Google Cloud Pub/Sub.

### Publisher

To use `Gcpc::Publisher`, pleaese initialize `Gcpc::Publisher` with some configurations.

```ruby
publisher = Gcpc::Publisher.new(
  project_id:  "<project id>",
  topic:       "<topic name>",
  credentials: "/path/to/credentials",
)
```

Then, simply call `Gcpc::Publisher#publish` to post a message!

```ruby
publisher.publish("<message payload>")
```

#### Interceptors

By using interceptors, you can add some functionality to the publisher.

For example, by adding `LogInterceptor` as below, you can add a logging feature.

```ruby
class LogInterceptor < Gcpc::Publisher::BaseInterceptor
  MyLogger = Logger.new(STDOUT)

  # @param [String] data
  # @param [Hash] attributes
  def publish(data, attributes)
    MyLogger.info "[Interceptor Log] publish data: \"#{data}\", attributes: #{attributes}"
    yield data, attributes
  end
end

publisher = Gcpc::Publisher.new(
  project_id:   "<project id>",
  topic:        "<topic name>",
  interceptors: [LogInterceptor],
  credentials:  "/path/to/credentials",
)

publisher.publish("<message payload>")
```

#### Publisher Example
A full example code is in [publisher-example](./examples/publisher-example). Please see it.

### Subscriber

To use `Gcpc::Subscriber`, pleaese initialize `Gcpc::Subscriber` with some configurations.

```ruby
subscriber = Gcpc::Subscriber.new(
  project_id:   "<project id>",
  subscription: "<subscription name>",
  credentials:  "/path/to/credentials",
)
```

Then, call `Gcpc::Subscriber#handle` to register a handler. A registered handler executes `#handle` callback for each published message.

```ruby
class NopHandler < Gcpc::Subscriber::BaseHandler
  # @param [Gcpc::Subscriber::Message] message
  def handle(message)
    # Do nothing. Consume only.
  end
end

subscriber.handle(NopHandler)
```

To start subscribing, please call `Gcpc::Subscriber#start`. It does not return, and run subscribing loops in it.

```ruby
subscriber.run
```

#### Signal Handling

By default, you can stop a subscriber process by sending `SIGINT`, `SIGTERM`, or `SIGKILL` signals.

If you want to use other signals, please pass signals to `#run`.

```ruby
subscriber.run(['SIGINT', 'SIGTERM', 'SIGSTOP', 'SIGTSTP'])
```

#### Interceptors

By using interceptors, you can add some functionality to the subscriber.

For example, by adding `LogInterceptor` as below, you can add a logging feature.

```ruby
class LogInterceptor < Gcpc::Subscriber::BaseInterceptor
  MyLogger = Logger.new(STDOUT)

  # @param [Gcpc::Subscriber::Message] message
  def handle(message)
    MyLogger.info "[Interceptor Log] subscribed a message: #{message}"
    yield message
  end
end

subscriber = Gcpc::Subscriber.new(
  project_id:   "<project id>",
  subscription: "<subscription name>",
  interceptors: [LogInterceptor],
  credentials:  "/path/to/credentials",
)
```

#### Subscriber Example
A full example code is in [subscriber-example](./examples/subscriber-example). Please see it.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/south37/gcpc.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

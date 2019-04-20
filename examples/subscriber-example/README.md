## subscriber example

An example code of `Gcpc::Subscriber`.

If you want to try `Gcpc`, please execute commands below in the root of this repository.

```
$ gcloud beta emulators pubsub start  # Please install Cloud Pub/Sub emulator from https://cloud.google.com/pubsub/docs/emulator for executing this.
$ bundle exec ruby examples/subscriber-example/subscriber-example.rb
$ bundle exec ruby examples/publisher-example/publisher-example.rb
```

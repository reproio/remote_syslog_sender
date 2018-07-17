Gem::Specification.new do |s|
  s.name              = 'remote_syslog_sender_tls'
  s.version           = '1.2.4'
  s.summary     = "Message sender that sends directly to a remote syslog endpoint"
  s.description = "Message sender that sends directly to a remote syslog endpoint (Support UDP, TCP, TCP+TLS)"

  s.authors  = ["Michelia Feng", "Tomohiro Hashidate", "Eric Lindvall"]
  s.email    = 'michelia.feng@gmail.com'
  s.homepage = 'https://github.com/aiwantaozi/remote_syslog_sender'

  s.files         = `git ls-files -z`.split("\x0")
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths = %w[lib]

  s.add_runtime_dependency 'syslog_protocol'

  s.add_development_dependency "bundler", "~> 1.6"
  s.add_development_dependency "rake"
  s.add_development_dependency "test-unit"
end

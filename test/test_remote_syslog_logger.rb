require File.expand_path('../helper', __FILE__)

class TestRemoteSyslogSender < Test::Unit::TestCase
  def setup
    @server_port = rand(50000) + 1024
    @socket = UDPSocket.new
    @socket.bind('127.0.0.1', @server_port)

    @tcp_server = TCPServer.open('127.0.0.1', 0)
    @tcp_server_port = @tcp_server.addr[1]

    @tcp_server_wait_thread = Thread.start do
      @tcp_server.accept
    end
  end

  def teardown
    @socket.close
    @tcp_server.close
  end

  def test_sender
    @sender = RemoteSyslogSender.new('127.0.0.1', @server_port)
    @sender.write "This is a test"

    message, _ = *@socket.recvfrom(1024)
    assert_match(/This is a test/, message)
  end

  def test_sender_long_payload
    @sender = RemoteSyslogSender.new('127.0.0.1', @server_port, packet_size: 10240)
    @sender.write "abcdefgh" * 1000

    message, _ = *@socket.recvfrom(10240)
    assert_match(/#{"abcdefgh" * 1000}/, message)
  end

  def test_sender_tcp
    @sender = RemoteSyslogSender.new('127.0.0.1', @tcp_server_port, protocol: :tcp)
    @sender.write "This is a test"
    sock = @tcp_server_wait_thread.value

    message, _ = *sock.recvfrom(1024)
    assert_match(/This is a test/, message)
  end

  def test_sender_tcp_nonblock
    @sender = RemoteSyslogSender.new('127.0.0.1', @tcp_server_port, protocol: :tcp, timeout: 20)
    @sender.write "This is a test"
    sock = @tcp_server_wait_thread.value

    message, _ = *sock.recvfrom(1024)
    assert_match(/This is a test/, message)
  end

  def test_sender_multiline
    @sender = RemoteSyslogSender.new('127.0.0.1', @server_port)
    @sender.write "This is a test\nThis is the second line"

    message, _ = *@socket.recvfrom(1024)
    assert_match(/This is a test/, message)

    message, _ = *@socket.recvfrom(1024)
    assert_match(/This is the second line/, message)
  end
end

class TestRemoteSyslogTLSSender < Test::Unit::TestCase
  def setup
    @key = OpenSSL::PKey::RSA.new(2048)
    @cert = OpenSSL::X509::Certificate.new
    @cert.version = 2
    @cert.serial = 1
    @cert.subject = OpenSSL::X509::Name.parse("/CN=localhost")
    @cert.issuer = @cert.subject
    @cert.public_key = @key.public_key
    @cert.not_before = Time.now
    @cert.not_after = Time.now + 3600
    @cert.sign(@key, OpenSSL::Digest::SHA256.new)

    tcp_server = TCPServer.open('127.0.0.1', 0)
    @tcp_server_port = tcp_server.addr[1]

    ctx = OpenSSL::SSL::SSLContext.new
    ctx.cert = @cert
    ctx.key = @key

    @ssl_server = OpenSSL::SSL::SSLServer.new(tcp_server, ctx)

    @tcp_server_wait_thread = Thread.start do
      @ssl_server.accept
    end
  end

  def teardown
    @ssl_server.close
  end

  def test_sender_tls_no_sni
    @sender = RemoteSyslogSender::TcpSender.new(
      '127.0.0.1',
      @tcp_server_port,
      tls: true,
      verify_mode: OpenSSL::SSL::VERIFY_NONE
    )

    @sender.write "This is a test"
    sock = @tcp_server_wait_thread.value

    message, _ = *sock.read_nonblock(256)
    assert_match(/This is a test/, message)

    # When remote hostname is an IP address, SNI hostname is not set.
    socket = @sender.instance_variable_get(:@socket)
    assert_nil(socket.hostname)
  end

  def test_sender_tls_sni
    @sender = RemoteSyslogSender::TcpSender.new(
      'localhost',
      @tcp_server_port,
      tls: true,
      verify_mode: OpenSSL::SSL::VERIFY_NONE
    )

    @sender.write "This is a test"
    sock = @tcp_server_wait_thread.value

    message, _ = *sock.read_nonblock(256)
    assert_match(/This is a test/, message)

    # When remote hostname is a hostname, SNI hostname is not set.
    socket = @sender.instance_variable_get(:@socket)
    assert_equal('localhost', socket.hostname)
  end
end

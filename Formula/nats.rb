class Nats < Formula
  desc "Utility to interact with and manage NATS messaging systems"
  homepage "https://github.com/nats-io/natscli"
  url "https://github.com/nats-io/natscli/archive/refs/tags/v0.5.1.tar.gz"
  sha256 "808a8905383949625e0a3f86821865eda29d381274021ff2d9ea7d7448c951fc"
  license "Apache-2.0"
  head "https://github.com/nats-io/natscli.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(ldflags: "-s -w -X main.version=#{version}"), "./nats"
    generate_completions_from_executable(bin/"nats", "--completion-script-",
                                        shells: [:bash, :zsh], shell_parameter_format: :none)
  end

  test do
    ENV["XDG_CONFIG_HOME"] = (testpath/"config").to_s
    assert_match version.to_s, shell_output("#{bin}/nats --version")
    system bin/"nats", "context", "save", "local", "--server=nats://127.0.0.1:4222", "--description=test"
    assert_match "local", shell_output("#{bin}/nats context ls")
  end
end

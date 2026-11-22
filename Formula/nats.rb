class Nats < Formula
  desc "Utility to interact with and manage NATS messaging systems"
  homepage "https://github.com/nats-io/natscli"
  url "https://github.com/nats-io/natscli/archive/refs/tags/v0.5.2.tar.gz"
  sha256 "6a735b879a19a7abaa4b45e512f23ddb7df6e8f1cd14b32091cd8568e4e94f63"
  license "Apache-2.0"
  head "https://github.com/nats-io/natscli.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.2"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "719eda37b610596650add8435f1efea9c50687fd02e785405bf1312d02747f4a"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "c101c4a5fe304b2aa9d21abf18bd26fe50755f4e825a5cb02786e84bd430ee54"
    sha256 cellar: :any,                 x86_64_linux: "e6ca22d84886abacbcbc40845487ddac6f3613bc7ec9a63ef44079bbea97b318"
  end

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(ldflags: "-s -w -X main.version=#{version}"), "./nats"
    generate_completions_from_executable(bin/"nats",
                                         shell_parameter_format: "--completion-script-",
                                         shells:                 [:bash, :zsh])
  end

  test do
    ENV["XDG_CONFIG_HOME"] = (testpath/"config").to_s
    assert_match version.to_s, shell_output("#{bin}/nats --version")
    system bin/"nats", "context", "save", "local", "--server=nats://127.0.0.1:4222", "--description=test"
    assert_match "local", shell_output("#{bin}/nats context ls")
  end
end

class Openssh < Formula
  desc "OpenBSD freely-licensed SSH connectivity tools built with LibreSSL"
  homepage "https://www.openssh.com/"
  url "https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-7.9p1.tar.gz"
  # sha256 "1a484bb15152c183bb2514e112aa30dd34138c3cfb032eee5490a66c507144ca"
  sha256 "6b4b3ba2253d84ed3771c8050728d597c91cfce898713beb7b64a305b6f11aad"
  head "https://github.com/openssh/openssh-portable.git"

  depends_on "libressl"
  depends_on "ldns" => :optional
  depends_on "pkg-config" => :build if build.with? "ldns"

  # Both of these patches are applied by Apple.
  patch do
    url "https://raw.githubusercontent.com/Homebrew/patches/1860b0a74/openssh/patch-sandbox-darwin.c-apple-sandbox-named-external.diff"
    sha256 "d886b98f99fd27e3157b02b5b57f3fb49f43fd33806195970d4567f12be66e71"
  end

  patch do
    url "https://raw.githubusercontent.com/Homebrew/patches/d8b2d8c2/openssh/patch-sshd.c-apple-sandbox-named-external.diff"
    sha256 "3505c58bf1e584c8af92d916fe5f3f1899a6b15cc64a00ddece1dc0874b2f78f"
  end

  resource "com.openssh.sshd.sb" do
    url "https://opensource.apple.com/source/OpenSSH/OpenSSH-209.50.1/com.openssh.sshd.sb"
    sha256 "a273f86360ea5da3910cfa4c118be931d10904267605cdd4b2055ced3a829774"
  end

  def install
    if build.head?
      ENV.append "CPPFLAGS", "-D__APPLE_SANDBOX_NAMED_EXTERNAL__"

      # Ensure sandbox profile prefix is correct.
      # We introduce this issue with patching, it's not an upstream bug.
      inreplace "sandbox-darwin.c", "@PREFIX@/share/openssh", etc/"ssh"

      args = %W[
      --with-libedit
      --with-kerberos5
      --prefix=#{prefix}
      --sysconfdir=#{etc}/ssh
      --with-pam
      --with-ssl-dir=#{Formula["libressl"].opt_prefix}
      ]

      args << "--with-ldns" if build.with? "ldns"
      
      system "/usr/local/bin/autoreconf"
      system "./configure", *args
      system "make"
      ENV.deparallelize
      system "make", "install"

      # This was removed by upstream with very little announcement and has
      # potential to break scripts, so recreate it for now.
      # Debian have done the same thing.
      bin.install_symlink bin/"ssh" => "slogin"

      buildpath.install resource("com.openssh.sshd.sb")
      (etc/"ssh").install "com.openssh.sshd.sb" => "org.openssh.sshd.sb"
    else
      odie "This version of OpenSSH is designed to be built from HEAD and with LibreSSL"
    end
  end

  test do
    assert_match "OpenSSH_", shell_output("#{bin}/ssh -V 2>&1")

    begin
      pid = fork { exec sbin/"sshd", "-D", "-p", "8022" }
      sleep 2
      assert_match "sshd", shell_output("lsof -i :8022")
    ensure
      Process.kill(9, pid)
      Process.wait(pid)
    end
  end
end

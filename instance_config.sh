#!/bin/bash

dnf update -y
dnf install -y httpd

# Habilitar CGI
dnf install -y mod_cgi

systemctl enable httpd
systemctl start httpd

# Crear estructura web
mkdir -p /var/www/html/assets
mkdir -p /var/www/cgi-bin

# Hora de arranque (esto sí es estático)
BOOT_TIME=$(date)

cat <<'EOF' > /var/www/cgi-bin/instance.sh
#!/bin/bash

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

echo "Content-type: text/plain"
echo
echo "$INSTANCE_ID"
EOF

chmod +x /var/www/cgi-bin/instance.sh

#HTML
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>EC2 Servers</title>
    <link rel="stylesheet" href="assets/style.css">
</head>
<body>
    <div class="card">
        <h1> Active EC2 Server</h1>

        <p><strong>Instance ID:</strong></p>
        <code id="instance-id">Loading...</code>

        <p><strong>Start time:</strong></p>
        <code>$BOOT_TIME</code>

        <footer>
            <p>Provided with Terraform</p>
        </footer>
    </div>

    <script>
        fetch('/cgi-bin/instance.sh')
            .then(res => res.text())
            .then(id => {
                document.getElementById('instance-id').innerText = id;
            })
            .catch(() => {
                document.getElementById('instance-id').innerText = 'No disponible';
            });
    </script>
</body>
</html>
EOF


# CSS
cat <<EOF > /var/www/html/assets/style.css
body {
    background: #0f172a;
    color: #e5e7eb;
    font-family: Arial, Helvetica, sans-serif;
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100vh;
}

.card {
    background: #020617;
    padding: 2rem 3rem;
    border-radius: 12px;
    box-shadow: 0 0 25px rgba(56, 189, 248, 0.3);
    text-align: center;
}

h1 {
    color: #38bdf8;
}

code {
    background: #020617;
    padding: 0.4rem 0.8rem;
    border-radius: 6px;
    display: inline-block;
    margin-top: 0.5rem;
}

footer {
    margin-top: 2rem;
    font-size: 0.8rem;
    color: #94a3b8;
}
EOF

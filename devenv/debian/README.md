# Development Container Setup

## Enterprise Devices

For enterprise devices which has endpoint security software intalled, the security software maybe decrypting the encrypted traffic and analyzing it. If the traffic is being analyzed, then it will be re-encrypted using the security sotware's root certificate.

In this case, the root certificate from the host software should also be included inside the container.

The `build.sh` script will copy contents of the `ROOTFS` to the container. Thus we can place the certificate there to copy and bundle the root certificates with the container image.

To copy into **Debian Container**, certificates should be places in `ROOTFS/usr/share/ca-certificates` directory.

> Certificate extension should be `.crt`. If the certificate has `.pem` extension, then rename the file with `.crt` extension.
> Example: ESET has CA cert with the following name- `ESET-SSL-Filter-CA.pem`. Copy the file to `ROOTFS/usr/share/ca-certificates\ESET-SSL-Filter-CA.crt`. Note that, `.pem` was renamed to `.crt`.

Location for certificates in **Debian Host**: `/etc/ssl/certs`.
Location for certificates in **Fedora Host**: `/etc/pki/ca-trust`.

To update the certificates, run `update-ca-certificates` after copying the certificates.
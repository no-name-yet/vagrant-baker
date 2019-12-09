FROM centos:7.7.1908

ENV VAGRANT_DEFAULT_PROVIDER=libvirt
ENV VAGRANT_USER=vagrant
ENV VAGRANT_USER_HOME=/home/vagrant
ENV VAGRANT_HOME="$VAGRANT_USER_HOME/.vagrant.d"
ENV VAGRANT_CWD="$VAGRANT_USER_HOME/app"

RUN \
	useradd -u 1001 -m -d "$VAGRANT_USER_HOME" "$VAGRANT_USER" \
	&& install -o "$VAGRANT_USER" -d "$VAGRANT_CWD" \
	&& yum --setopt=skip_missing_names_on_install=False -y \
		--setopt=install_weak_deps=False \
		install \
		https://releases.hashicorp.com/vagrant/2.2.6/vagrant_2.2.6_x86_64.rpm \
		libvirt-devel ruby-devel gcc libxslt-devel libxml2-devel make \
		python3-pip \
		libvirt qemu-kvm rsync sudo openssh-clients \
	&& runuser -u "$VAGRANT_USER" -p -- vagrant plugin install vagrant-libvirt \
	&& python3 -m pip install dumb-init==1.2.2 \
	&& yum -y remove \
		libvirt-devel ruby-devel gcc libxslt-devel libxml2-devel \
		python3-pip \*-headers \*-devel \
	&& yum clean all

COPY sbin/ /sbin/
COPY etc/ /etc/

ENTRYPOINT ["/usr/local/bin/dumb-init", "/sbin/entrypoint.sh"]

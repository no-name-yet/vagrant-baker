FROM quay.io/pod_utils/vagrant-baker-base

ENV CONTAINER_RUN_ROOT=/var/run/containers/storage
ENV CONTAINER_GRAPH_ROOT=/workspace/.containers/storage

RUN \
	yum --setopt=skip_missing_names_on_install=False -y \
		--setopt=install_weak_deps=False \
		install buildah skopeo \
	&& yum clean all

COPY sbin/ /sbin/
COPY etc/ /etc/

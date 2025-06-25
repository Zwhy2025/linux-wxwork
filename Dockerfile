FROM ubuntu:22.04

# -----------------------------------------------------------------------------
# 基础环境配置
# -----------------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
	LANG=zh_CN.UTF-8 \
	container=docker \
	TERM=xterm-256color

WORKDIR /workspace

COPY env/*.sh /tmp/

RUN bash /tmp/install_base.sh

RUN bash /tmp/install_dev.sh

RUN bash /tmp/install_graphics.sh

RUN bash /tmp/install_wine.sh   

RUN bash /tmp/install_wxwork.sh

RUN rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/cache/apt/* && \
    rm -rf /var/cache/apt/archives/*
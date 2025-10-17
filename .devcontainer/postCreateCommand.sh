#!/bin/bash

rustup target add aarch64-unknown-linux-gnu
rustup target add arm-unknown-linux-gnueabihf
pip3 install -r .devcontainer/requirements.txt

git clone https://github.com/ryuz/vitisenv.git ~/.vitisenv
echo 'export PATH="$HOME/.vitisenv/bin:$PATH"' >> ~/.bashrc
~/.vitisenv/bin/vitisenv global 2023.2

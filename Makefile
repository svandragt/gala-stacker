BUILD_DIR := build
PLUGIN_DIR := /usr/lib/x86_64-linux-gnu/gala/plugins
SWITCHBOARD_PLUG_DIR := /usr/lib/x86_64-linux-gnu/switchboard-3/personal
SCHEMA_DIR := /usr/share/glib-2.0/schemas
SCHEMA := org.pantheon.desktop.gala.plugins.stacker.gschema.xml

.PHONY: all setup build test install uninstall clean lint format

all: build

setup:
	meson setup $(BUILD_DIR)

build: setup
	ninja -C $(BUILD_DIR)

test: build
	meson test -C $(BUILD_DIR)

install: build
	sudo ninja -C $(BUILD_DIR) install

uninstall:
	sudo rm -f $(PLUGIN_DIR)/libgala-stacker.so
	sudo rm -f $(SWITCHBOARD_PLUG_DIR)/libstacker-settings.so
	sudo rm -f $(SCHEMA_DIR)/$(SCHEMA)
	sudo glib-compile-schemas $(SCHEMA_DIR)

clean:
	rm -rf $(BUILD_DIR)

lint:
	io.elementary.vala-lint src/*.vala switchboard-plug/*.vala

format:
	io.elementary.vala-lint -f src/*.vala switchboard-plug/*.vala

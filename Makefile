BUILD_DIR := build
PLUGIN_DIR := /usr/lib/x86_64-linux-gnu/gala/plugins
SCHEMA_DIR := /usr/share/glib-2.0/schemas
SCHEMA := org.pantheon.desktop.gala.plugins.paperwm.gschema.xml

.PHONY: all setup build install uninstall reload clean

all: build

setup:
	meson setup $(BUILD_DIR)

build: setup
	ninja -C $(BUILD_DIR)

install: build
	sudo ninja -C $(BUILD_DIR) install

uninstall:
	sudo rm -f $(PLUGIN_DIR)/libgala-paperwm.so
	sudo rm -f $(SCHEMA_DIR)/$(SCHEMA)
	sudo glib-compile-schemas $(SCHEMA_DIR)

reload:
	systemctl --user kill -s SIGKILL io.elementary.gala@x11.service

clean:
	rm -rf $(BUILD_DIR)

BUILD_DIR := build
PLUGIN_DIR := /usr/lib/x86_64-linux-gnu/gala/plugins
SCHEMA_DIR := /usr/share/glib-2.0/schemas
SCHEMA := org.pantheon.desktop.gala.plugins.stacker.gschema.xml

.PHONY: all setup build install uninstall clean

all: build

setup:
	meson setup $(BUILD_DIR)

build: setup
	ninja -C $(BUILD_DIR)

install: build
	sudo ninja -C $(BUILD_DIR) install

uninstall:
	sudo rm -f $(PLUGIN_DIR)/libgala-stacker.so
	sudo rm -f $(SCHEMA_DIR)/$(SCHEMA)
	sudo glib-compile-schemas $(SCHEMA_DIR)

clean:
	rm -rf $(BUILD_DIR)

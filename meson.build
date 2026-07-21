project('gala-paperwm', 'vala', 'c', version: '0.1.0')

gnome = import('gnome')

gala_dep = dependency('gala')
libmutter_dep = dependency('libmutter-14')
mutter_dep = [
    libmutter_dep,
    dependency('mutter-mtk-14'),
    dependency('mutter-cogl-14'),
    dependency('mutter-cogl-pango-14'),
    dependency('mutter-clutter-14'),
]

plugins_dir = gala_dep.get_variable(pkgconfig: 'libdir') / 'gala' / 'plugins'
mutter_typelib_dir = libmutter_dep.get_variable(pkgconfig: 'typelibdir')

# Ubuntu's libmutter-14-dev ships no Vala vapi; Gala vendors and maintains
# its own in-tree, so point valac at a Gala source checkout's copy.
gala_vapi_dir = get_option('gala_vapi_dir')
add_project_arguments([
    '--vapidir', gala_vapi_dir,
    '--define', 'HAS_MUTTER43',
    '--define', 'HAS_MUTTER44',
    '--define', 'HAS_MUTTER45',
    '--define', 'HAS_MUTTER46',
], language: 'vala')

install_data(
    'data/org.pantheon.desktop.gala.plugins.paperwm.gschema.xml',
    install_dir: get_option('datadir') / 'glib-2.0' / 'schemas',
)

shared_library('gala-paperwm',
    files(
        'src/Main.vala',
        'src/Row.vala',
        'src/FocusRing.vala',
    ),
    dependencies: [gala_dep, dependency('gee-0.8'), dependency('gio-unix-2.0'), dependency('pango'), dependency('pangocairo'), dependency('gdk-pixbuf-2.0')] + mutter_dep,
    install: true,
    install_dir: plugins_dir,
    install_rpath: mutter_typelib_dir,
)

gnome.post_install(glib_compile_schemas: true)

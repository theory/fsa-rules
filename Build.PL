use Module::Build;

my $build = Module::Build->new(
    module_name        => 'FSA::Rules',
    license            => 'perl',
    create_makefile_pl => 'passthrough',
    create_readme      => 1,
    configure_requires => { 'Module::Build' => '0.2701' },
    build_requires     => { 'Test::More'    => '0.17'   },
    recommends         => {
        'GraphViz'   => '2.00',
        'Text::Wrap' => 0,
        'Storable'   => '2.05',
        'Test::Pod'  => '1.20'
    },

);
$build->create_build_script;

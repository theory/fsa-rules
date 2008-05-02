use Module::Build;

my $build = Module::Build->new(
    module_name        => 'FSA::Rules',
    license            => 'perl',
    create_makefile_pl => 'passthrough',
    create_readme      => 1,
    requires           => { perl            => '5.6.2'  },
    configure_requires => { 'Module::Build' => '0.2701' },
    build_requires     => {
        'Module::Build' => '0.2701',
        'Test::More'    => '0.17',
    },
    recommends         => {
        'GraphViz'       => '2.00',
        'Text::Wrap'     => 0,
        'Storable'       => '2.05',
        'B::Deparse'     => '0.61',
        'Test::Pod'      => '1.20',
        'Test::Spelling' => 0,
      },

);
$build->create_build_script;

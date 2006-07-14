use Module::Build;

my $build = Module::Build->new(
    module_name => 'FSA::Rules',
    license     => 'perl',
    requires    => { },
    recommends  => {
        'GraphViz'   => '2.00',
        'Text::Wrap' => 0,
        'Storable'   => '2.05',
    },
    build_requires     => { Test::Simple => '0.17' },
    create_makefile_pl => 'passthrough',
#    create_readme      => 1,
);
$build->create_build_script;

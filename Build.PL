use Module::Build;

my $build = Module::Build->new(
    module_name        => 'FSA::Rules',
    license            => 'perl',
    requires           => { Clone => '0.15' },
    recommends         => { GraphViz => '2.00' },
    build_requires     => { Test::Simple  => '0.17' },
    create_makefile_pl => 'passthrough',
    create_readme     => 1,
);
$build->create_build_script;

use Module::Build;

my $build = Module::Build->new(
    module_name        => 'FSA::Machine',
    license            => 'perl',
    build_requires     => { Test::Simple  => '0.17' },
    create_makefile_pl => 'passthrough',
    create_readme     => 1,
);
$build->create_build_script;

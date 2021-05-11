NAME
====

CroX::Red::JsonAPI - blah blah blah

SYNOPSIS
========

```raku
use Cro::HTTP::Router;
use Cro::HTTP::Server;
use CroX::Red::JsonAPI;

use Red;

model Ble {...}
model Bla {
		has UInt $.id   is serial;
		has Str  $.col  is column;
		has Ble  @.bles is relationship{ .bla-id };
}
model Ble {
		has UInt $!id        is serial;
		has Str  $.other-col is column;
		has UInt $!bla-id    is referencing(*.id, :model(Bla));
		has Bla  $!bla       is relationship{ .bla-id };
}

$GLOBAL::RED-DB    = database "SQLite";

schema(Bla, Ble).create;

Bla.^create: :col<blablabla>, :bles[ { :other-col<bla> }, { :other-col<pla> } ];
Bla.^create: :col<blebleble>, :bles[ { :other-col<ble> } ];
Bla.^create: :col<bliblibli>, :bles[ { :other-col<bli> } ];
Bla.^create: :col<blobloblo>, :bles[ { :other-col<blo> } ];
Bla.^create: :col<blublublu>, :bles[ { :other-col<blu> } ];

my $application = route {
		json-api(Bla, Ble, :base-url<http://localhost:20001>);
}
my Cro::Service $http = Cro::HTTP::Server.new: :port(20001), :$application;
$http.start;

say "Access http://localhost:20001/bla";

react whenever signal(SIGINT) {
		$http.stop;
		exit;
}
```

DESCRIPTION
===========

CroX::Red::JsonAPI is ...

AUTHOR
======

Fernando Corrêa de Oliveira <fernando.correa@humanstate.com>

COPYRIGHT AND LICENSE
=====================

Copyright 2020 Fernando Corrêa de Oliveira

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.


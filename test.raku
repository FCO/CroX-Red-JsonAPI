use Cro::HTTP::Router;
use Cro::HTTP::Server;
use CroX::Red::JsonAPI;

use Red;

model Ble {...}
model Bla {
		has $.id   is serial;
		has $.col  is column;
		has @.bles is relationship(*.bla-id, :model<Ble>);
}
model Ble {
		has $!id        is serial;
		has $.other-col is column;
		has $!bla-id    is referencing(*.id, :model<Bla>);
		has $!bla       is relationship(*.bla-id, :model<Bla>);
}

$GLOBAL::RED-DB    = database "SQLite";
$GLOBAL::RED-DEBUG = True;

schema(Bla, Ble).create;

Bla.^create: :col<blablabla>, :bles[ { :other-col<bla> }, { :other-col<pla> } ];
Bla.^create: :col<blebleble>, :bles[ { :other-col<ble> } ];
Bla.^create: :col<bliblibli>, :bles[ { :other-col<bli> } ];
Bla.^create: :col<blobloblo>, :bles[ { :other-col<blo> } ];
Bla.^create: :col<blublublu>, :bles[ { :other-col<blu> } ];

my $application = route {
		json-api(schema(Bla), :base-url<http://localhost:20001>);
		get -> {
				content 'text/plain', "Hello world!\n";
		}
}
my Cro::Service $http = Cro::HTTP::Server.new: :port(20001), :$application;
$http.start;
react whenever signal(SIGINT) {
		$http.stop;
		exit;
}

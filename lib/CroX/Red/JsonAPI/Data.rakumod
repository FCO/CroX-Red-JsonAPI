use JSON::Class;
unit class CroX::Red::JsonAPI::Data does JSON::Class;

class Link does JSON::Class {
	has Str $.href is required;
	has     %.meta;
}

class Relationship does JSON::Class {
	has %.links is json-skip-null;
	has $.data  is json-skip-null;
	has %.meta  is json-skip-null;
}

class Resource does JSON::Class {
	has              $.id            is json-skip-null;
	has Str          $.type          is required;
	has              %.attributes    is json-skip-null;
	has Relationship %.relationships is json-skip-null;
}

class Pagination does JSON::Class {
	has $.first where Str|Link;
	has $.last  where Str|Link;
	has $.prev  where Str|Link;
	has $.next  where Str|Link;
}

class Links does JSON::Class {
	has            $.self       where Str|Link;
	has            $.related    where Str|Link;
	has            $.about      where Str|Link;
	has Pagination $.pagination handles <first last prev next>;
}

class Source does JSON::Class {
	has Str $.pointer;
	has Str $.parameter;
}

class Error does JSON::Class {
	has        $.id;
	has Links  $.links;
	has UInt   $.status;
	has        $.code;
	has Str    $.title;
	has Source $.source;
	has        %.meta;
}

has          $.data     is json-skip-null;
has Error    @.error    is json-skip-null;
has          %.meta     is json-skip-null;
has          $.jsonapi  is json-skip-null;
has          %.links    is json-skip-null;
has          @.included is json-skip-null;

submethod TWEAK(:$data, :@error, :%meta, :$jsonapi, :%links, :@includes) {
	die "You cant have data and error at the same tinme" if  $data.defined &&  @error;
	die "You need at least 1 of data and error defined"  if !$data.defined && !@error;
	die "You can't have included if no data is defined"  if !$data.defined &&  @includes;
}

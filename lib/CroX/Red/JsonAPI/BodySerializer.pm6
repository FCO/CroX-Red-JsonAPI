use CroX::Red::JsonAPI::Data;
use Cro::HTTP::BodySerializers;
use Cro::HTTP::Router;
use Red::Model;
use Red::ResultSeq;

unit class CroX::Red::JsonAPI::BodySerializer does Cro::HTTP::BodySerializer;

has Str $.base-url = "";

submethod TWEAK(|) { $!base-url .= subst: /"/"$/, "" }

method resultseq-to-positional(
		Red::ResultSeq:D $seq,
		Bool :$root,
		Bool :$attrs = $root,
		:%inc,
		:$self
		--> Positional
) {
	$seq.Seq.map({
		self.model-to-resource:
				$_,
				:$root,
				:$attrs,
				:%inc,
				:self(
					$self
						?? "$self/{ .^id-values.join: "-" }"
						!! "{ $!base-url }/{ .^name.lc }/{ .^id-values.join: "-" }"
				),
	}).list
}

method relationships(
		Red::Model:D $model,
		%inc,
		$self = "{ $!base-url }/{ $model.^name.lc }/{ $model.^id-values.join: "-" }"
		--> Hash()
) {
	do for $model.^relationships.keys -> $attr {
		my $name = $attr.name.substr: 2;
		my @rel := $model."$name"() if %inc{ $name }:exists;
		$*included ∪= self.resultseq-to-positional:
				@rel,
				:!root,
				:attrs,
				|(:inc($_) with %inc{$name}),
		if %inc{$name}:exists;
		$name => CroX::Red::JsonAPI::Data::Relationship.new:
			|(
				data  => self.resultseq-to-positional:
						@rel,
						:!root,
				if %inc{$name}:exists
			),
			links => {
				:self("{ $self }/relationships/{ $name }"),
				:related("{ $self }/{ $name }"),
			}
	}
}

method model-to-resource(
		Red::Model:D $model,
		Bool :$root,
		Bool :$attrs = $root,
		:%inc,
		:$self
		--> CroX::Red::JsonAPI::Data::Resource
) {
	with $model {
		CroX::Red::JsonAPI::Data::Resource.new:
			:id(.^id-values.join: "-"),
			:type(.^name.lc),
			|(
				:attributes(
						.^columns>>.column.grep({
							!.id && .attr.has_accessor
						})
						.map({
							.attr-name => $model."{ .attr-name }"()
						}).Hash
				) if $attrs
			),
			:relationships(self.relationships: $model, %inc),
			:links{ :$self },
	}
}

method is-applicable(Cro::HTTP::Message $message, $body --> Bool) {
    with $message.content-type {
        (
		$body ~~ Red::Model
		|| (
			$body ~~ Positional
			&& $body.<>.all ~~ Red::Model
		)
	)
	&& 'application/vnd.api+json' eq .type-and-subtype.lc
    } else {
        False
    }
}

method inc-to-hash(@inc --> Hash()) {
	my %hash;
	my @list;
	for @inc {
		if .contains: "." {
			my ($key, $value) = .split: /<.ws> "," <.ws>/, 2;
			@list.push: $key;
			%hash{ $key }.push: $value
		} else {
			%hash{ $_ } = {}
		}
	}
	for @list {
		%hash{ $_ } = self.inc-to-hash: %hash{ $_ }<>
	}
	%hash
}

method serialize(Cro::HTTP::Message $message, $ans --> Supply) {
	my $self = $!base-url ~ request.path;
	my %inc  = do with request.query-value: "include" {
		self.inc-to-hash: .split: /<.ws> "," <.ws>/;
	}
    my Set $*included;
    my %plus;
    my $data = do if $ans ~~ Red::ResultSeq {
        self.resultseq-to-positional: $ans, :root, :%inc, :$self
    } else {
        self.model-to-resource: $ans, :root, :%inc, :$self
    }
    my $answer = CroX::Red::JsonAPI::Data.new(:$data, :links{ :$self, |(%*links // {}) }, :included($*included.keys), |%plus);
    my $json = $answer.to-json.encode('utf-8');
    self!set-content-length($message, $json.bytes);
    supply { emit $json }
}

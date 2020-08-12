use CroX::Red::JsonAPI::Data;
use Cro::HTTP::BodySerializers;
use Cro::HTTP::Router;
use Red::AST::Infixes;
use Red::AST::Value;
use Red::Model;
use Red::ResultSeq;

unit class CroX::Red::JsonAPI::BodySerializer does Cro::HTTP::BodySerializer;

#class X::Code {
#	has $.code
#}

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
#	X::Code.new(:400code).throw unless %inc ⊆ $model.^relationships.keys;
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

method serialize(Cro::HTTP::Message $message, $ans is copy --> Supply) {
	my $self = $!base-url ~ request.path;
	my %inc  = do with request.query-value: "include" {
		self.inc-to-hash: .split: /<.ws> "," <.ws>/;
	}
	my @sort = .split(/<.ws> "," <.ws>/).map: { @( .split: "." ) } with request.query-value("sort");
    my Set $*included;
    my %plus;
    my $data = do if $ans ~~ Red::ResultSeq {
		if @sort {
			$ans .= sort: -> $model {
				do for @sort {
					my $a = $model	;
					$a .= "{ .subst: /^ "-"/, "" }"() for .<>;
					.head.starts-with("-")
						?? Red::AST::Mul.new: ast-value(-1), $a
						!! $a
				}
			}
		}
        self.resultseq-to-positional: $ans, :root, :%inc, :$self
    } else {
        self.model-to-resource: $ans, :root, :%inc, :$self
    }
    my $answer = CroX::Red::JsonAPI::Data.new(:$data, :links{ :$self, |(%*links // {}) }, :included($*included.keys), |%plus);
    my $json = $answer.to-json.encode('utf-8');
    self!set-content-length($message, $json.bytes);
#	CATCH {
#		when X::Code {
#			$message.status = .code
#		}
#	}
    supply { emit $json }
}

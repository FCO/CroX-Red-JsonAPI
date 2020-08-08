use CroX::Red::JsonAPI::Data;
use Cro::HTTP::BodySerializers;
use Cro::HTTP::Router;
use Red::Model;
use Red::ResultSeq;

unit class Cro::HTTP::BodySerializer::JsonAPI does Cro::HTTP::BodySerializer;

has Str $.base-url = "";

submethod TWEAK(|) { $!base-url .= subst: /"/"$/, "" }

method resultseq-to-positional(Red::ResultSeq:D $seq, Bool :$root --> Positional) {
	$seq.Seq.map({ self.model-to-resource: $_, :$root }).list
}

method relationships(Red::Model $model, Bool :$add --> Hash()) {
	do for $model.^relationships.keys -> $attr {
		my $name = $attr.name.substr: 2;
		my @rel  = $model."$name"();
		$*included ∪= @rel.Seq.map: { self.model-to-resource: $_, :!root, :attrs };
		$name => CroX::Red::JsonAPI::Data::Relationship.new:
			data  => @rel.map: { self.model-to-resource: $_, :!root },
			links => {
				:self($!base-url ~ "{ request.target }/relationships/{ $name }"),
				:related($!base-url ~ "{ request.target }/{ $name }"),
			}
	}
}

method model-to-resource(Red::Model:D $model, Bool :$root, Bool :$relationships = $root, Bool :$attrs = $root --> CroX::Red::JsonAPI::Data::Resource) {
	with $model {
		CroX::Red::JsonAPI::Data::Resource.new:
			:id(.^id-values.join: "-"),
			:type(.^name.lc),
			|(:attributes(.^columns>>.column.grep({ !.id && .attr.has_accessor }).map({ .attr-name => $model."{ .attr-name }"() }).Hash) if $attrs),
			|(:relationships(self.relationships: $model) if $relationships),
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

method serialize(Cro::HTTP::Message $message, $ans --> Supply) {
    my Set $*included;
    my %plus;
    my $data = do if $ans ~~ Red::ResultSeq {
        self.resultseq-to-positional: $ans, :root
    } else {
        self.model-to-resource: $ans, :root
    }
    my $answer = CroX::Red::JsonAPI::Data.new(:$data, :links{ :self($!base-url ~ request.target), |(%*links // {}) }, :included($*included.keys), |%plus);
    my $json = $answer.to-json.encode('utf-8');
    self!set-content-length($message, $json.bytes);
    supply { emit $json }
}

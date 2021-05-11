use Red::Schema;
use CroX::Red::JsonAPI::Data;
use Cro::HTTP::Router;
use CroX::Red::JsonAPI::BodySerializer;

multi json-api(+@models, :$base-url) is export {
	json-api schema(|@models), |(:$base-url with $base-url)
}
multi json-api(Red::Schema $schema, :$base-url) is export {
	body-serializer CroX::Red::JsonAPI::BodySerializer.new: :base-url($base-url.subst: /"/"$/, "");
	my %models = $schema.models.kv.map: *.lc => *;
	get -> Str $resource where { %models{$_}:exists } {
		content 'application/vnd.api+json', %models{$resource}.^all
	}
	get -> Str $resource where { %models{$_}:exists }, $id {
		content 'application/vnd.api+json', %models{$resource}.^load: $id
	}
	get -> Str $resource where { %models{$_}:exists }, $id, "relationships", Str $to-one-name where { %models{$resource}.^can: $_ } {
		content 'application/vnd.api+json', %models{$resource}.^load($id)."$to-one-name"()
	}
	get -> Str $resource where { %models{$_}:exists }, $id, Str $to-one-name where { %models{$resource}.^can: $_ } {
		content 'application/vnd.api+json', %models{$_}.^load($id)."$to-one-name"()
	}
}

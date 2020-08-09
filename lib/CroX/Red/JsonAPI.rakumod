use Red::Schema;
use CroX::Red::JsonAPI::Data;
use Cro::HTTP::Router;
use CroX::Red::JsonAPI::BodySerializer;

sub json-api(Red::Schema $schema, :$base-url) is export {
	body-serializer CroX::Red::JsonAPI::BodySerializer.new: :base-url($base-url.subst: /"/"$/, "");

	for $schema.models.kv -> $name, $model {
		get -> Str $resource where $name.lc {
			content 'application/vnd.api+json', $model.^all
		}
		get -> Str $resource where $name.lc, $id {
			content 'application/vnd.api+json', $model.^load: $id
		}
		for $model.^has-one-relationships -> $to-one {
			get -> Str $resource where $name.lc, $id, "relationships", Str $to-one-name where $to-one.name.substr: 2 {
				content 'application/vnd.api+json', $model.^load($id)."$to-one-name"()
			}
			get -> Str $resource where $name.lc, $id, Str $to-one-name where $to-one.name.substr: 2 {
				content 'application/vnd.api+json', $model.^load($id)."$to-one-name"()
			}
		}
		for $model.^has-many-relationships -> $to-many {
			get -> Str $resource where $name.lc, $id, "relationships", Str $to-many-name where $to-many.name.substr: 2 {
				content 'application/vnd.api+json', $model.^load($id)."$to-many-name"()
			}
			get -> Str $resource where $name.lc, $id, Str $to-many-name where $to-many.name.substr: 2 {
				content 'application/vnd.api+json', $model.^load($id)."$to-many-name"()
			}
		}
	}
}

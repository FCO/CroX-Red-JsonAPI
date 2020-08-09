use CroX::Red::JsonAPI::Data;

unit class CroX::Red::JsonAPI::BodyParser does Cro::BodyParser;

method is-applicable(Cro::HTTP::Message $message --> Bool) {
    with $message.content-type {
        'application/vnd.api+json' eq .type-and-subtype.lc
    } else {
        False
    }
}

method parse(Cro::HTTP::Message $message --> Promise) {
    Promise(supply {
        my $payload = Blob.new;
        whenever $message.body-byte-stream -> $blob {
            $payload ~= $blob;
    	    LAST emit CroX::Red::JsonAPI::Data.from-json($payload.decode('utf-8'));
        }
    })
}

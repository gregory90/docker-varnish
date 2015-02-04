vcl 4.0;

import directors;

backend default {
    .host = "${VARNISH_BACKEND_IP}";
    .port = "${VARNISH_BACKEND_PORT}";
}

sub vcl_init {
    new cluster1 = directors.round_robin();
    cluster1.add_backend(default);
}

acl invalidators {
    "localhost";
    "${VARNISH_BACKEND_IP}";
}

sub vcl_recv {
    unset req.http.cookie;

    if (req.method == "PURGE") {
        if (!client.ip ~ invalidators) {
            return (synth(405, "Not allowed"));
        }
        return (purge);
    }

    if (req.http.Cache-Control ~ "no-cache" && client.ip ~ invalidators) {
        set req.hash_always_miss = true;
    }

    if (req.method == "BAN") {
        if (!client.ip ~ invalidators) {
            return (synth(405, "Not allowed"));
        }

            ban("obj.http.x-host ~ " + req.http.x-host
                + " && obj.http.x-url ~ " + req.http.x-url
                + " && obj.http.content-type ~ " + req.http.x-content-type
            );

        return (synth(200, "Banned"));
    }
}


sub vcl_backend_response {

    # Set ban-lurker friendly custom headers
    set beresp.http.x-url = bereq.url;
    set beresp.http.x-host = bereq.http.host;
}

sub vcl_deliver {
    # Keep ban-lurker headers only if debugging is enabled
    if (!resp.http.x-cache-debug) {
        # Remove ban-lurker friendly custom headers when delivering to client
        unset resp.http.x-url;
        unset resp.http.x-host;
    }
    if (resp.http.x-varnish ~ " ") {
        set resp.http.x-cache = "HIT";
    } else {
        set resp.http.x-cache = "MISS";
    }
}

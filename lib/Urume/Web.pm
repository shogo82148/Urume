package Urume::Web;

use strict;
use warnings;
use utf8;
use Kossy;
use Config::PL ();
use JSON;
use Net::IP;
use Log::Minimal;
use Urume::Storage;

filter 'auto' => sub {
    my $app = shift;
    sub {
        my ( $self, $c )  = @_;
        $c->stash->{config} = $self->config;
        my $storage = Urume::Storage->new(
            config => $self->config,
        );
        $self->storage($storage);
        $app->($self, $c);
    }
};

get '/' => [qw/auto/] => sub {
    my ( $self, $c )  = @_;

    my @vms = $self->storage->list_vm;
    $c->render( 'index.tx', {
        vms => \@vms,
    });
};

get '/dnsmasq.conf' => [qw/auto/] => sub {
    my ( $self, $c )  = @_;

    my @vms = $self->storage->list_vm;
    $c->render( 'dnsmasq.conf.tx', {
        vms => \@vms,
    });
    $c->res->content_type("text/plain; charset=utf8");
    $c->res;
};

post '/vm/register' => [qw/auto/] => sub {
    my ( $self, $c )  = @_;

    my %args
        = map { $_ => scalar $c->req->param($_) }
            qw/ name host base /;
    my $vm = $self->storage->register_vm(%args);

    $c->render_json($vm);
};

get '/vm/info/:name' => [qw/auto/] => sub {
    my ( $self, $c )  = @_;
    my $name = $c->args->{name};

    my $vm = $self->storage->get_vm( name => $name );
    $c->halt(404) unless $vm;

    $c->render_json($vm);
};

post '/vm/info/:name' => [qw/auto/] => sub {
    my ( $self, $c )  = @_;
    my $name = $c->args->{name};

    my $vm = $self->storage->get_vm( name => $name );
    $c->halt(404) unless $vm;

    $self->storage->set_vm_info(
        $name => {
            active => $c->req->param("active") ? JSON::true : JSON::false,
        }
    );

    $vm = $self->storage->get_vm( name => $name );
    $c->render_json($vm);
};

post '/vm/stop/:name' => [qw/auto/] => sub {
    my ( $self, $c )  = @_;
    my $name = $c->args->{name};

    my $vm = $self->storage->get_vm( name => $name );
    $c->halt(404) unless $vm;

    $self->storage->stop_vm( name => $name );
};

post '/vm/start/:name' => [qw/auto/] => sub {
    my ( $self, $c )  = @_;
    my $name = $c->args->{name};

    my $vm = $self->storage->get_vm( name => $name );
    $c->halt(404) unless $vm;

    $self->storage->start_vm( name => $name );
};

post '/init' => [qw/auto/] => sub {
    my ( $self, $c )  = @_;
    $self->storage->init_ip_addr_pool;
    $c->render_json({ ok => JSON::true });
};

get '/config' => sub {
    my ( $self, $c )  = @_;
    $c->render_json( $self->config );
};

our $Config = {};
sub config {
    my $class = shift;
    my @args  = @_;
    return $Config unless @args;

    for my $cfg ( @args ) {
        if (ref $cfg && ref $cfg eq "HASH") {
            $Config = { %$Config, %$cfg };
        }
        else {
            $Config = { %$Config, %{ Config::PL::config_do($cfg) } };
        }
    }
    $Config;
}

sub storage {
    my $self = shift;
    $self->{_storage} = $_[0] if @_;
    $self->{_storage};
}

1;

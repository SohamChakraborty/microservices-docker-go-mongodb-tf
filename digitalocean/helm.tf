resource "helm_release" "external-dns" {
  provider   = helm.cinema
  depends_on = [digitalocean_kubernetes_cluster.cinema, kubernetes_namespace.external-dns]
  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "v6.9.0"
  namespace  = "external-dns"
  timeout    = 120
  set {
    name  = "provider"
    value = "digitalocean"
  }
  set_sensitive {
    name  = "digitalocean.apiToken"
    value = var.do_token 
  }
  set {
    name  = "rbac.create"
    value = "true"
  }
  set {
    name  = "domainFilters"
    value = "{${var.domain_name[0]}}" 
  }
  set {
    name  = "sources"
    value = "{ingress,service}"
  }
  /* 
   set {
    name  = "istio-ingress-gateway"
    value = "istio-system/istio-ingressgateway"
  }
 */
}

resource "helm_release" "cert-manager" {
  provider   = helm.cinema
  depends_on = [kubernetes_namespace.cert-manager]
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.9.1"
  namespace  = "kube-system"
  timeout    = 120
  set {
    name  = "createCustomResource"
    value = "true"
  }
  set {
    name  = "installCRDs"
    value = "true"
  }
}

/*
resource "helm_release" "istio-base" {
  provider        = helm.cinema
  repository      = local.istio-repo
  name            = "istio-base"
  chart           = "base"
  cleanup_on_fail = true
  force_update    = true
  namespace       = kubernetes_namespace.istio-system.metadata.0.name
  depends_on      = [kubernetes_namespace.istio-system]
}

resource "helm_release" "istiod" {
  provider        = helm.cinema
  repository      = local.istio-repo
  name            = "istiod"
  chart           = "istiod"
  cleanup_on_fail = true
  force_update    = true
  namespace       = kubernetes_namespace.istio-system.metadata.0.name
  set {
    name  = "meshConfig.accessLogFile"
    value = "/dev/stdout"
  }
  set {
    name  = "grafana.enabled"
    value = "true"
  }
  set {
    name  = "kiali.enabled"
    value = "true"
  }
  set {
    name  = "servicegraph.enabled"
    value = "true"
  }
  set {
    name  = "tracing.enabled"
    value = "true"
  }
  depends_on = [helm_release.istio-base]
}

resource "helm_release" "istio-ingress" {
  provider        = helm.cinema
  repository      = local.istio-repo
  name            = "istio-ingressgateway"
  chart           = "gateway"
  cleanup_on_fail = true
  force_update    = true
  namespace       = kubernetes_namespace.istio-system.metadata.0.name
  depends_on      = [helm_release.istiod]
}

resource "helm_release" "istio-egress" {
  provider   = helm.cinema
  repository = local.istio-repo
  name       = "istio-egressgateway"
  chart      = "gateway"
  cleanup_on_fail = true
  force_update    = true
  namespace       = kubernetes_namespace.istio-system.metadata.0.name
  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  depends_on = [helm_release.istiod]
}

resource "helm_release" "bookinfo" {
  provider   = helm.cinema
  repository = local.bookinfo-repo
  name       = "bookinfo"
  chart      = "istio-bookinfo"
  cleanup_on_fail = true
  force_update    = true
  namespace       = kubernetes_namespace.devingress.metadata.0.name
  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  set {
    name  = "gateway.selector"
    value = "ingressgateway"
  }
  set {
    name  = "gateway.hostname"
    value = var.domain_name[0]
  }
  depends_on = [helm_release.istiod]
}
*/

resource "helm_release" "argocd" {
  depends_on = [kubernetes_namespace.argocd]
  provider   = helm.cinema
  repository = local.argocd-repo
  namespace  = "argocd"
  name       = "argocd"
  chart      = "argo-cd"
  cleanup_on_fail = true
  force_update    = true
}

resource "helm_release" "cluster-issuer" {
  provider  = helm.cinema
  name      = "cluster-issuer"
  chart     = "../charts/cluster-issuer"
  namespace = "kube-system"
  depends_on = [
    helm_release.cert-manager,
    digitalocean_kubernetes_cluster.cinema,
  ]
  set_sensitive {
    name  = "zerossl_email"
    value = var.zerossl_email
  }
  set_sensitive {
    name  = "zerossl_eab_hmac_key"
    value = var.zerossl_eab_hmac_key
  }
  set_sensitive {
    name  = "zerossl_eab_hmac_key_id"
    value = var.zerossl_eab_hmac_key_id
  }
}

resource "helm_release" "nginx-ingress-chart" {
  provider   = helm.cinema
  name       = "nginx-ingress-controller"
  namespace  = "default"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "service.annotations.kubernetes\\.digitalocean\\.com/load-balancer-id"
    value = digitalocean_loadbalancer.ingress_load_balancer.id
  }
  set {
    name  = "service.beta.kubernetes.io/do-loadbalancer-hostname"
    value = "terraform.${var.domain_name[0]}"
  }

  depends_on = [
    digitalocean_loadbalancer.ingress_load_balancer
  ]
}

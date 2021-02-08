{{- define "imagePullSecret" }}
{{- printf "{\"auths\": {\"%s\": {\"username\": \"%s\",\"password\": \"%s\",\"auth\": \"%s\"}}}" .Values.images.registry .Values.images.username .Values.images.password (printf "%s:%s" .Values.images.username .Values.images.password | b64enc) | b64enc }}
{{- end }}
{{- define "swaggerUrls" }}
{{- printf "[{ url: \"https://api.%s/v2/deployments/swagger-json\", name: \"Deployments\" }, { url: \"https://api.%s/v2/repositories/swagger-json\", name: \"Repositories\" }, { url: \"https://api.%s/v2/workspaces/swagger-json\", name: \"Workspaces\" }, { url: \"https://api.%s/v2/inference/swagger-json\", name: \"Inference\" }, { url: \"https://api.%s/v2/logs/swagger-json\", name: \"Logs\" }, { url: \"https://api.%s/v2/tokens/swagger-json\", name: \"Tokens\" }, { url: \"https://api.%s/v2/users/swagger-json\", name: \"Users\" }]" .Values.host .Values.host .Values.host .Values.host .Values.host .Values.host .Values.host | quote }}
{{- end }}
{{- define "minioDomain" }}
{{- printf "deeploy-minio.deeploy.svc.cluster.local" | quote }}
{{- end }}
{{- define "kubeConfig"}}
{{- printf "apiVersion: v1\nclusters:\n- cluster:\n    certificate-authority-data: <CERTIFICATE-AUTH>\n    server: https://kubernetes.default.svc\n  name: deeploy-cluster\ncontexts:\n- context:\n    cluster: deeploy-cluster\n    user: kfserving\n  name: deeploy\ncurrent-context: deeploy\nkind: Config\npreferences: {}\nusers:\n- name: kfserving\n  user:\n    token: <TOKEN>\n" | quote }}
{{- end }}
{{- define "frontendEnv"}}
{{- printf "(function(window) {\n  window.__env = window.__env || {};\n  window.__env.production = true;\n  window.__env.repositoryServiceURL = 'https://api.%s/v2';\n  window.__env.introspectorServiceUrl = 'https://api.%s/v2';\n  window.__env.authorizationServiceUrl = 'https://api.%s/v2';\n  window.__env.workspaceServiceURL = 'https://api.%s/v2';\n  window.__env.kratosURL = 'https://api.%s/v1/auth';\n  window.__env.deploymentServiceURL = 'https://api.%s/v2';\n  window.__env.userServiceURL = 'https://api.%s/v2';\n  window.__env.loggerServiceURL = 'https://api.%s/v2';\n  window.__env.docsServiceURL = 'https://docs.%s/';\n  window.__env.tokenServiceURL = 'https://api.%s/v2';\n})(this);\n" .Values.host .Values.host .Values.host .Values.host .Values.host .Values.host .Values.host .Values.host .Values.host .Values.host | quote }}
{{- end }}
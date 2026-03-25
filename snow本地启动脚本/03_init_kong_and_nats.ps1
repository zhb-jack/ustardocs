. (Join-Path $PSScriptRoot '_common.ps1')

Write-Step 'Init Kong services and routes'
$kongItems = @(
  @{ ServiceName = 'auth-service'; RouteName = 'auth-service-route'; Url = 'http://host.docker.internal:18001'; Path = '/auth' },
  @{ ServiceName = 'tenant-api'; RouteName = 'tenant-api-route'; Url = 'http://host.docker.internal:18002'; Path = '/api' },
  @{ ServiceName = 'admin-service'; RouteName = 'admin-service-route'; Url = 'http://host.docker.internal:18003'; Path = '/admin' },
  @{ ServiceName = 'tenant-admin-service'; RouteName = 'tenant-admin-service-route'; Url = 'http://host.docker.internal:18004'; Path = '/tenant-admin' },
  @{ ServiceName = 'webhook-service'; RouteName = 'webhook-service-route'; Url = 'http://host.docker.internal:18005'; Path = '/webhook' }
)

foreach ($item in $kongItems) {
  Ensure-KongService -Name $item.ServiceName -Url $item.Url
  Ensure-KongRoute -ServiceName $item.ServiceName -RouteName $item.RouteName -Path $item.Path
}

Write-Step 'Init NATS JetStream streams'
$tempDir = Get-ToolsTempDir
$goFile = Join-Path $tempDir 'init_nats_streams.go'
@'
package main

import (
  "context"
  "fmt"
  "time"

  cfgpkg "nh/wallet/pkg/config"
  natspkg "nh/wallet/pkg/nats"

  "github.com/nats-io/nats.go/jetstream"
)

func main() {
  cfg := &cfgpkg.NATSConfig{
    URL:           "nats://host.docker.internal:4222",
    ClusterID:     "nh-wallet-cluster",
    ClientID:      "snow-local-stream-init",
    MaxReconnect:  3,
    ReconnectWait: 2 * time.Second,
    Timeout:       5 * time.Second,
  }

  client, err := natspkg.NewClient(cfg)
  if err != nil {
    panic(err)
  }
  defer client.Close()

  publisher := natspkg.NewPublisher(client)
  ctx := context.Background()
  streams := []natspkg.StreamConfig{
    natspkg.WalletStreamConfig,
    natspkg.AddressStreamConfig,
    natspkg.DepositStreamConfig,
    natspkg.WithdrawStreamConfig,
    natspkg.CallbackStreamConfig,
    natspkg.AuditStreamConfig,
    natspkg.TenantStreamConfig,
    natspkg.CollectStreamConfig,
  }

  for _, s := range streams {
    _, err := publisher.CreateStream(ctx, jetstream.StreamConfig{
      Name:        s.Name,
      Description: s.Description,
      Subjects:    s.Subjects,
      MaxAge:      s.MaxAge,
      MaxMsgs:     s.MaxMsgs,
      MaxBytes:    s.MaxBytes,
      Replicas:    s.Replicas,
      Storage:     jetstream.FileStorage,
      Retention:   jetstream.LimitsPolicy,
    })
    if err != nil {
      fmt.Printf("STREAM %s => %v\n", s.Name, err)
    } else {
      fmt.Printf("STREAM %s => created\n", s.Name)
    }
  }
}
'@ | Set-Content -Path $goFile -Encoding UTF8

& docker run --rm --entrypoint /bin/sh `
  -v "$(Get-BackendRoot):/src" `
  -v "${tempDir}:/work" `
  -w /src `
  golang:1.24 `
  -lc "export PATH=/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin && go run /work/init_nats_streams.go"

if ($LASTEXITCODE -ne 0) {
  throw 'NATS stream initialization failed'
}

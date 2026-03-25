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

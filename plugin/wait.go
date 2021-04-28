package plugin

import (
	"context"
	"fmt"
	"time"

	"github.com/digitalocean/godo"
	"github.com/hashicorp/go-hclog"
)

func waitForDropletState(
	desiredState string, dropletId int,
	client *godo.Client,
	log hclog.Logger,
	timeout time.Duration) error {
	done := make(chan struct{})
	defer close(done)

	result := make(chan error, 1)
	go func() {
		attempts := 0
		for {
			attempts += 1

			log.Debug(fmt.Sprintf("Checking droplet status... (attempt: %d)", attempts))
			droplet, _, err := client.Droplets.Get(context.TODO(), dropletId)
			if err != nil {
				result <- err
				return
			}

			if droplet.Status == desiredState {
				result <- nil
				return
			}

			// Wait 3 seconds in between
			time.Sleep(3 * time.Second)

			// Verify we shouldn't exit
			select {
			case <-done:
				// We finished, so just exit the goroutine
				return
			default:
				// Keep going
			}
		}
	}()

	log.Debug(fmt.Sprintf("Waiting for up to %d seconds for droplet to become %s", timeout/time.Second, desiredState))
	select {
	case err := <-result:
		return err
	case <-time.After(timeout):
		err := fmt.Errorf("timeout while waiting to for droplet to become '%s'", desiredState)
		return err
	}
}

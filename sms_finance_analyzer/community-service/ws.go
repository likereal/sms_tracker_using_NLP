package main

import (
	"context"
	// "net/http"
	"time"

	"github.com/coder/websocket"
	"github.com/labstack/echo/v4"
)

// how to encrypt chats?
//

func WebSocketHandler(hub *Hub) echo.HandlerFunc {
	return func(c echo.Context) error {
		// Upgrade connection
		conn, err := websocket.Accept(c.Response(), c.Request(), &websocket.AcceptOptions{
			OriginPatterns: []string{"*"},
		})
		if err != nil {
			return err
		}

		ctx, cancel := context.WithTimeout(c.Request().Context(), time.Minute*10)
		defer cancel()

		client := &Client{
			Conn: conn,
			Send: make(chan []byte, 256),
			Hub:  hub,
		}

		hub.Register <- client

		// Load last 50 messages from Redis and send to client
		msgs, err := RedisClient.LRange(Ctx, "chat:messages", -50, -1).Result()
		if err == nil {
			for _, m := range msgs {
				// Decrypt before sending
				decrypted, err := Decrypt(m)
				if err == nil {
					client.Send <- []byte(decrypted)
				}
			}
		}

		go client.WriteLoop(ctx)
		client.ReadLoop(ctx)

		return nil
	}
}

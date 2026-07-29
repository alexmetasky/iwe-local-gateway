# Demo Feature — Backend Part

> Демонстрация параллельной работы Claude Code + Gemini через `iwe-local-gateway` (DP.SC.034/035).

Автор этого файла: Claude Code. Написан параллельно с `demo-feature-frontend.md` (автор: Gemini),
пока каждый агент держал lock на свой файл и был виден другому через `list_peer_statuses`.

## Что здесь могло бы быть

Условная backend-часть демо-фичи: endpoint, который принимает статус peer-агента и отдаёт его
списком — собственно то, что уже реализовано в `iwe-local-gateway` как `update_peer_status` /
`list_peer_statuses`.


### Testnet-конфигурация Supra CLI
1. Скопируйте шаблон supra/configs/testnet.yaml в локальный файл supra/configs/testnet.local.yaml, который не отслеживается Git.
2. В локальной копии заполните реальные ccount_address и private_key. Файл в репозитории должен оставаться без секретов.
3. При запуске Supra CLI указывайте локальный профиль, например:
   docker compose run --rm supra_cli --config supra/configs/testnet.local.yaml ... или экспортируйте SUPRA_PROFILE_CONFIG на путь к файлу.
4. При необходимости передавайте ключи через переменные окружения или секреты CI, не записывая их в репозиторий.

> What happened my bot isn't responding to commands 

------

1. Make sure the commande exit in your codebase and not some typo 

2. If using polling make sure bot token is set correctly and doesnt send to many request has telecr will rate limit to many request If using the rate limit plugin

3. if using webhook make sure the path is set correctly and  ssl is configured properly if using vps you might wanna check the bin/ for telecr built in cli for ssl 

> if this still doesnt fix the issue open a pr or discussion here at github 

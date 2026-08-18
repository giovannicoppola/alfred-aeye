The goal of this project is to create an Alfred workflow to return current usage toward limits of AI services. currently
supported: Cursor and Claude. 
- backend: a script using the cursor-usage (cursor, https://github.com/javaisbetterthanpython/cursor-usage) and https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor (claude) to obtain current usage toward quota limits
- package this in a JSON output that can be shown by Alfred
- we need to vet (check code for both packages) for possible unexpected on unsafe actions.
- both packages should be bundled with the Alfred workflow so that no extra istallation steps are needed 

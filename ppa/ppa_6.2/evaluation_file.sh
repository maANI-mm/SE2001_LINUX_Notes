#!/bin/bash

err(){
  echo "Error: $*"
  exit 1
}

req=( "mktemp" "diff" "basename" "col" "find" "pushd" "popd" )
executable="myCount.sh"
for i in "${req[@]}"; do
  command -v "$i" > /dev/null 2>&1 || err "$i is not installed"
done

ppa=$(basename "$PWD")
ppa_path="/opt/se2001/$ppa"

[[ -d "$ppa_path" ]] || err "PPA not found at $ppa_path"

test_type="$1"
test_type=${test_type:-"public"}
test_type=${test_type%/}

cat >script.sh <<EOF
#!/bin/bash

rand_dir=\$(mktemp -d XXXXXX)
pushd "\$rand_dir" > /dev/null || exit 1

cat > somefile.txt

exec="../\$(dirname "\${BASH_SOURCE[0]}")/$executable"

[[ -r "\$exec" ]] || exit 1

if grep "wc|awk" "\$exec" &>/dev/null ; then
  echo "Do not use wc or awk in your script"
else
  bash "\$exec" -l somefile.txt 2>&1 < /dev/null
  bash "\$exec" -w somefile.txt 2>&1 < /dev/null
  bash "\$exec" -n somefile.txt 2>&1 < /dev/null
  bash "\$exec" -s say somefile.txt 2>&1 < /dev/null
  bash "\$exec" -l -n somefile.txt 2>&1 < /dev/null
  bash "\$exec" -l -s say -l -n somefile.txt 2>&1 < /dev/null
fi

popd > /dev/null || exit 1
[[ -d "\$rand_dir" ]] && rm "\${rand_dir?}" -rf
EOF
chmod u+x script.sh

if [[ $test_type == "private" ]]; then
  redir="/dev/null"
else
  redir="/dev/stdout"
fi
echo "${test_type^} Test Cases:"
if [[ ! -d "$ppa_path/$test_type" ]]; then
  err "No $test_type test cases found"
fi
tc=0
passed=0
IFS=$'\n'
for test_path in $(find "$ppa_path/$test_type" -type d -name "test_case_*" | sort ); do
  ((tc++))
  echo -n "Test Case $tc: "
  input_path="$test_path/input.txt"
  output_path="$test_path/output.txt"
  if [[ ! -f "$output_path" ]]; then
    echo "Output file for $input_path not found at $output_path"
    continue
  fi
  if diff --color=always <( ./script.sh < "$input_path" | col) <( col < "$output_path" ) &>$redir ; then
    echo "Passed!"
    ((passed++))
  else
    echo "Failed :("
  fi
done
if [[ $tc -eq 0 ]]; then
  err "No $test_type test cases found"
fi
if [[ $passed -eq $tc ]]; then
  echo "All $test_type test cases passed!"
else
  echo "$passed/$tc $test_type test cases passed"
  exit 1
fi

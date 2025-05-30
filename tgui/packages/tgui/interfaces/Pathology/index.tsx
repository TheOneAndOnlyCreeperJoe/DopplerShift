import { useState } from 'react';
import { useBackend } from 'tgui/backend';
import { Window } from 'tgui/layouts';
import {
  Button,
  DmIcon,
  Icon,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';

type Item = {
  key: string;
  specialtext: string;
  desc: string;
  name: string;
  amount: number;
  icon: string;
  icon_state: string;
  cost: number;
  category: string;
};

type Data = {
  contents: Record<string, Item>;
  time: string;
  health: number;
  color: string;
};

export const Pathology = (props, context) => {
  const { act, data } = useBackend<Data>();
  const contents = Object.values(data.contents);

  const [tab, setTab] = useState<
    'essentials' | 'chemicals' | 'virusbottles' | 'symptominducers'
  >('essentials');

  const displayedItems = contents.filter(
    (item) => item.category?.toLowerCase() === tab,
  );

  return (
    <Window width={650} height={700}>
      <Window.Content scrollable>
        <Section title="Health status">
          <NoticeBox>Next shop rotation in: {data.time}!</NoticeBox>
          <LabeledList>
            <LabeledList.Item label="Health">{data.health}</LabeledList.Item>
            <LabeledList.Item label="Color">{data.color}</LabeledList.Item>
            <LabeledList.Item label="Button">
              <Button
                content="Dispatch a 'test' action"
                onClick={() => act('test')}
              />
            </LabeledList.Item>
          </LabeledList>
        </Section>

        <Section title="Pathology Store">
          <Tabs>
            <Tabs.Tab
              selected={tab === 'essentials'}
              onClick={() => setTab('essentials')}
            >
              Essentials
            </Tabs.Tab>
            <Tabs.Tab
              selected={tab === 'chemicals'}
              onClick={() => setTab('chemicals')}
            >
              Chemicals
            </Tabs.Tab>
            <Tabs.Tab
              selected={tab === 'virusbottles'}
              onClick={() => setTab('virusbottles')}
            >
              Virus Bottles
            </Tabs.Tab>
            <Tabs.Tab
              selected={tab === 'symptominducers'}
              onClick={() => setTab('symptominducers')}
            >
              Syptom Inducers
            </Tabs.Tab>
          </Tabs>

          {!displayedItems.length ? (
            <NoticeBox>No items found in this category.</NoticeBox>
          ) : (
            <Stack vertical>
              {displayedItems.map((item) => (
                <ItemRow key={item.key} item={item} />
              ))}
            </Stack>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};

const ItemRow = ({ item }) => {
  const { act } = useBackend<Data>();
  return (
    <Stack
      align="center"
      justify="space-between"
      mb={1}
      style={{ borderBottom: '1px solid #444', paddingBottom: '0.3rem' }}
    >
      <Stack.Item>
        <DmIcon
          icon={item.icon}
          icon_state={item.icon_state}
          verticalAlign="middle"
          height={'32px'}
          width={'32px'}
          fallback={<Icon name="spinner" size={2} spin />}
        />
      </Stack.Item>

      <Stack.Item grow pl={1}>
        {item.name} <br />
        <Stack.Item fontSize={0.75}>
          <i>{item.specialtext}</i>
        </Stack.Item>
      </Stack.Item>

      <Stack.Item color="label" fontSize="10px">
        <Button
          mt={-1}
          color="transparent"
          icon="info"
          tooltipPosition="right"
          tooltip={item.desc}
        />
        <br />
      </Stack.Item>

      <Stack.Item>
        <Stack vertical align="center">
          <Stack.Item fontSize={0.75}>{item.cost}PP</Stack.Item>
          <Stack.Item>
            <Button
              content="Buy"
              onClick={() =>
                act('buy', {
                  key: item.key,
                  cost: item.cost,
                })
              }
            />
          </Stack.Item>
        </Stack>
      </Stack.Item>
    </Stack>
  );
};
